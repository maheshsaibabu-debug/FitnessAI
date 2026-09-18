# Fitness Companion

Offline-first AI fitness companion. Plan → Do → Track → Check in → Adapt → Motivate → Progress. The device is the primary runtime; Supabase is a sync/backup/AI enhancement, never a requirement for core functionality. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design.

## Status

This is an independent, from-scratch codebase, built in phases (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §12). Currently landed:

- ✅ Project scaffold, clean-architecture folder layout, dependencies
- ✅ Local Drift/SQLite schema (33 tables) — [docs/DATABASE.md](docs/DATABASE.md)
- ✅ Supabase Postgres schema + RLS, verified against a scratch Postgres instance — [docs/SECURITY.md](docs/SECURITY.md)
- ✅ Sync engine (outbox pattern, idempotent uploads, conflict policy) — [docs/SYNC_ENGINE.md](docs/SYNC_ENGINE.md), [docs/SYNC_CONFLICTS.md](docs/SYNC_CONFLICTS.md)
- ✅ App shell: theme, routing (go_router + bottom nav), Riverpod DI, connectivity monitor, offline banner — verified running on iOS Simulator
- ⏳ Everything feature-shaped (onboarding data collection, deterministic fitness engines, workout execution, health integrations, nutrition, accountability, AI coach, progress, notifications, community) is not yet built — see the phase list and the acceptance checklist in the product brief.

Nothing in this repo fakes a feature that isn't built yet: unbuilt screens say so explicitly instead of showing mock data.

## Getting started

```bash
flutter pub get
cp .env.example .env   # fill in a real Supabase project URL + anon/publishable key
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Project layout

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) §2. Short version: `core/` is cross-cutting infrastructure, `domain/` is pure-Dart deterministic engines, `data/` bridges local (Drift) and remote (Supabase), `features/` is UI, `ai/` is the LLM provider abstraction.

## Testing

```bash
flutter analyze
flutter test
```

`test/unit/app_database_test.dart` exercises the local schema directly (round-trip, idempotency, append-only history). `test/widget_test.dart` exercises the app shell. See [docs/TEST_PLAN.md](docs/TEST_PLAN.md) for what's covered vs. still pending.

## Documentation

| Doc | Covers |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Stack, structure, phased rollout, trade-offs |
| [DATABASE.md](docs/DATABASE.md) | Local + cloud schema |
| [OFFLINE_FIRST.md](docs/OFFLINE_FIRST.md) | What must work with no network, and why it does |
| [SYNC_ENGINE.md](docs/SYNC_ENGINE.md) | Outbox, retry/backoff, triggers |
| [SYNC_CONFLICTS.md](docs/SYNC_CONFLICTS.md) | Per-entity conflict resolution policy |
| [AI_ARCHITECTURE.md](docs/AI_ARCHITECTURE.md) | Provider abstraction, context resolver, fallback (design contract for phase 11) |
| [SECURITY.md](docs/SECURITY.md) | Auth, secrets, RLS, verification results |
| [PRIVACY.md](docs/PRIVACY.md) | Health-data handling rules |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | Coverage by layer, what's still blocked and on what |
