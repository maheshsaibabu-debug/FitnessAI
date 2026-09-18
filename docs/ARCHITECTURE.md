# Architecture Report — Fitness Companion

Status: living document, reflects actual implementation as of each commit. Written before feature code so subsequent work has a fixed reference; update it when the implementation diverges.

## 1. Technology Stack

| Layer | Choice | Why |
|---|---|---|
| Client | Flutter 3.44 / Dart 3.12 | Single codebase for iOS + Android, mature offline story |
| State management | Riverpod 2 (+ codegen) | Compile-time-safe DI, testable providers, no BuildContext coupling for business logic |
| Routing | go_router | Declarative, deep-link friendly, works with Riverpod redirect guards |
| Local database | Drift (SQLite) | Typed queries, migrations, reactive streams — becomes the operational source of truth while offline |
| Cloud backend | Supabase (Postgres + Auth + RLS + Edge Functions) | Managed Postgres with row-level security maps cleanly onto per-user fitness data; edge functions host the AI gateway |
| Health data | `health` package (HealthKit / Health Connect) | Single Dart API over both platforms |
| Notifications | `flutter_local_notifications` (core) + Supabase/FCM/APNs (enhancement only) | Local notifications must work with zero connectivity |
| Models | Freezed + json_serializable | Immutable domain models, exhaustive pattern matching for state machines (task status, sync status, etc.) |
| Charts | fl_chart | Renders from local data, no network dependency |

No LLM vendor is hard-coded — see §7.

## 2. Project Structure

```
lib/
  core/        # cross-cutting: database, sync, connectivity, notifications, health, security, analytics, errors, config
  domain/      # pure-Dart deterministic engines (no Flutter, no network, no LLM)
  data/        # local (Drift DAOs), remote (Supabase clients), repositories (merge local+remote)
  features/    # one folder per UI feature, each with presentation + feature-local state
  ai/          # provider abstraction, context resolver, prompts, offline fallback
  shared/      # theme, reusable widgets, utilities
```

Dependency rule: `features` → `domain` + `data` (via repositories) → `core`. Features never talk to Drift or Supabase directly; they go through a repository interface. `domain` engines never import Flutter, Supabase, or an HTTP client — they take plain Dart values in and return plain Dart values out, which is what makes them independently testable and offline-safe by construction.

## 3. Local Database Architecture

Drift/SQLite is the **operational source of truth** whenever the device is offline. Every entity in §7 of the product spec (UserProfile, WorkoutPlan, DailyTask, WeightLog, SyncQueue, etc.) is a Drift table with a UUID primary key (`TEXT`, generated client-side with `uuid`) plus `created_at` / `updated_at` (UTC epoch millis). The UI reads exclusively from Drift's reactive `Stream` queries — never waits on a network round trip. See [DATABASE.md](DATABASE.md) for the full schema.

## 4. Supabase / Cloud Architecture

Mirrors the local schema per user, scoped by `auth.uid()` via RLS on every table. Supabase provides: auth, backup/restore, multi-device sync target, community/challenge tables (shared, not per-device), and an Edge Function acting as the AI gateway (keeps LLM API keys server-side, never shipped in the client binary). See [DATABASE.md](DATABASE.md) and [SECURITY.md](SECURITY.md).

## 5. Synchronization Architecture

```
User Action → Local DB write (immediate) → SyncQueue row (outbox) → Connectivity available? → SyncEngine drains queue → Supabase
```

The UI never blocks on this path — it renders from the local write, full stop. A background `SyncEngine` (triggered on connectivity-regained, app-resume, and a periodic timer) drains the `sync_queue` table in order, one event at a time, marking each `pending → in_flight → done|failed`. Failures use exponential backoff and stay in the queue; the queue is durable across app restarts because it's just another Drift table. See [SYNC_ENGINE.md](SYNC_ENGINE.md).

## 6. Conflict Resolution Strategy

No single blanket policy — different entities have different correct merge semantics:

- **Append-only events** (workout completion, set logged, PR recorded, check-in): idempotent by client-generated `event_id`; server uses `ON CONFLICT (event_id) DO NOTHING`. Never overwritten, never merged — a duplicate upload is just a no-op.
- **Time-series logs** (weight, body measurements): each entry is its own row keyed by `(user_id, metric, recorded_at)`; two devices logging at different timestamps both survive. No "latest wins" that would silently drop data.
- **Mutable singletons** (user profile, active plan): last-write-wins by `updated_at`, with the update also carrying a monotonic client `version` counter to break same-millisecond ties deterministically.
- **Historical performance** (exercise progression): treated as an event stream, never mutated in place, so there is nothing to "conflict" — new data appends.

Full policy table with rationale: [SYNC_CONFLICTS.md](SYNC_CONFLICTS.md).

## 7. AI Strategy

```
AIProvider (abstract)
├── CloudAIProvider      -> Supabase Edge Function -> configurable LLM (no vendor hard-coded in the client)
├── OnDeviceAIProvider    -> optional, behind a capability flag, for future on-device models
└── RuleBasedFallbackProvider -> pure Dart, always available, wraps the deterministic domain engines
```

The deterministic engines in `domain/` (progression, adaptive planning, streaks, PRs, nutrition math) are authoritative and never delegate arithmetic to an LLM. The LLM's job is exclusively language: motivation copy, explaining *why* a plan changed, conversational Q&A, meal-alternative suggestions. A `FitnessContextResolver` assembles a bounded, summarized context object (recent performance, adherence, trend deltas — not raw historical rows) before any cloud call, so token spend stays predictable and old history never leaks unsummarized into a prompt. If the cloud call fails or the device is offline, the app falls back to the rule-based provider and always returns something useful, never a bare error string. See [AI_ARCHITECTURE.md](AI_ARCHITECTURE.md).

## 8. Health Integration Strategy

`HealthRepository` wraps the `health` plugin (HealthKit on iOS, Health Connect on Android) behind one interface. Steps/workouts read from the platform API write into the local `step_record` table on a schedule and on app-resume; the rest of the app only ever reads Drift, never the health plugin directly, so a denied permission degrades to manual entry rather than breaking the screen. See [OFFLINE_FIRST.md](OFFLINE_FIRST.md).

## 9. Notification Architecture

`flutter_local_notifications` is the primary system — scheduled locally from on-device logic (today's plan, evening check-in, streak risk), so it works with the radio off. Push (via Supabase → FCM/APNs) is strictly additive, for cases like a coach message arriving while the app is closed. Quiet hours and per-category frequency limits are enforced locally before anything is scheduled.

## 10. Security Model

- Supabase Auth issues the session; the JWT/refresh token is stored via `flutter_secure_storage` (Keychain/Keystore), never in plain SharedPreferences.
- Every user-owned Postgres table has RLS restricting `SELECT/INSERT/UPDATE/DELETE` to `auth.uid() = user_id`; community/challenge tables use explicit visibility columns.
- No service-role key ever ships in the client; privileged operations (if any) live only in Edge Functions.
- Health data is minimized at the source (only fields the app actually uses are read), never sent to the AI gateway wholesale, and never logged to analytics.

Full detail: [SECURITY.md](SECURITY.md), [PRIVACY.md](PRIVACY.md).

## 11. Testing Strategy

- **Unit**: every `domain/` engine is pure Dart — tested with plain `flutter_test`/table-driven cases, no widget pump needed (progression math, streak math, nutrition math, adaptive-plan rules).
- **Widget**: key screens under each of loading/loaded/empty/error/offline states.
- **Integration**: the offline-first scenario in §47 of the product spec, executed end-to-end (airplane mode → full onboarding → workout → weight log → app kill/relaunch → reconnect → verify sync with no duplicates).
- RLS is tested with two seeded Supabase users asserting cross-user reads/writes are rejected.

Full plan: [TEST_PLAN.md](TEST_PLAN.md).

## 12. Implementation Phases

Following the product spec's §51 process, in this exact codebase, committing at each stable milestone:

1. ✅ Discovery + this report
2. ✅ Architecture docs
3. Local Drift schema + Supabase schema/RLS/migrations
4. Foundation: theme, routing, Riverpod setup, error handling, repository abstraction, connectivity monitor, sync engine skeleton
5. Onboarding flow
6. Deterministic fitness engines
7. Workout generation + execution
8. Health/steps integration
9. Nutrition + meal tracking
10. Accountability: daily tasks, check-ins, adaptive planning
11. AI coach (cloud + offline fallback)
12. Progress, charts, PRs
13. Motivation engine + local notifications
14. Community/challenges (kept from breaking offline core)
15. Hardening: security review, performance, offline/sync test suite, accessibility

Each phase lands as its own commits; this file and the checklist in the product brief track what's actually done vs. still pending — nothing is marked complete until it runs.

## 13. Risks and Trade-offs

- **Drift + Supabase schema drift**: two schemas must stay semantically aligned by hand (Drift has no native Postgres codegen bridge). Mitigation: both schemas documented together in [DATABASE.md](DATABASE.md) and changed in the same commit.
- **`health` plugin platform variance**: HealthKit and Health Connect have different permission models and background-delivery guarantees; steps may lag on Android without a foreground service. Mitigation: treat health data as "best effort enhancement," never gate core flows on it, allow manual entry always.
- **Sync engine correctness is the highest-risk component** in an offline-first app — most real bugs in this category show up under partial connectivity, not full-offline or full-online. Mitigation: the interrupted-sync and multi-day-offline scenarios in §47 are first-class integration tests, not an afterthought.
- **AI cost/latency vs. context quality**: richer context improves coaching relevance but costs tokens/latency. Mitigation: `FitnessContextResolver` summarizes rather than dumps raw history, with an explicit size budget.
- **Scope**: the full product brief (56 sections) is a multi-week+ commercial build. This repo is being built incrementally, phase by phase, with each phase genuinely working before the next starts — not stubbed to look complete.
