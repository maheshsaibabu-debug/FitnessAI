# Offline-First

## The rule

The app must never depend on the internet for core fitness functionality. Concretely: every screen and interaction listed below reads and writes exclusively through `AppDatabase` (Drift/SQLite). Nothing in that path awaits a `SupabaseClient` call, checks connectivity before proceeding, or shows a blocking spinner tied to a network request.

## What must work with the radio off

Per the product brief §6: app launch, cached session, profile, today's plan, workout execution, exercise library, strength/body-weight/HIIT tracking, on-device step reads, weight/measurement/nutrition logging, daily check-in, workout completion/skip, streaks, PRs, progress charts, local motivation copy, local reminders, adaptive-plan recalculation, and all historical data. Each of these is backed by a table in `lib/core/database/tables/` (see [DATABASE.md](DATABASE.md)) queried via a `Stream` so the UI updates the instant the local write commits.

## How a write actually flows (implemented)

```
Repository method
  -> db.transaction(() async {
       await db.into(table).insert(...);          // the real data
       await syncQueueRepository.enqueue(...);      // the outbox entry
     });
  -> UI's StreamProvider re-emits from the local query, already updated
  -> (later, if online) SyncEngine.drainQueue() uploads the outbox entry
```

Both writes happen in one Drift transaction so an app kill between them is impossible — either both landed or neither did.

## What "online" is used for

Connectivity (`lib/core/connectivity/connectivity_monitor.dart`) drives exactly three things: (1) triggering `SyncEngine.drainQueue()`, (2) the subtle offline banner (`lib/shared/widgets/offline_banner.dart`), (3) gating features that are inherently server-side (AI coach cloud calls, community/challenges, push notification registration). It gates nothing else — no screen in `features/` checks connectivity before letting the user act.

## Verified so far

- App launches and reaches the home shell with `.env` pointed at an unreachable Supabase URL (`Supabase.initialize` wrapped in try/catch in `main.dart`) — confirmed on iOS Simulator.
- Local schema round-trips real writes, including the outbox and its idempotency constraint (`test/unit/app_database_test.dart`, and a scratch-Postgres RLS/idempotency check — see [SECURITY.md](SECURITY.md)).

## Not yet verified (tracked for phase 15 hardening)

The full 20-step offline/sync scenario in the product brief §47 (multi-day offline use, interrupted sync, app termination mid-sync, reconnect-and-verify-no-duplicates against a real Supabase project) requires the feature code that doesn't exist yet (workout execution, check-ins, etc.) and a live Supabase project. It is scheduled as integration tests once those phases land — see [TEST_PLAN.md](TEST_PLAN.md).
