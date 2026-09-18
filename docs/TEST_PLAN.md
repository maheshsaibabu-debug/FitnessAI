# Test Plan

## Unit — `domain/` engines

Every engine in `lib/domain/` is pure Dart (no Flutter, no network) and gets table-driven `flutter_test` coverage as it's built: progression math (target/actual/RPE -> next recommendation), streak counting, PR detection, nutrition target formulas, adaptive-plan rule application. None of these need a widget pump or a database.

## Unit/integration — local database

`test/unit/app_database_test.dart` (implemented): Drift schema round-trips real data, the sync-queue outbox is queryable by status, a duplicate `event_id` insert is rejected by the schema (idempotency enforced at the DB layer, not just app logic), and an append-only stream (`exercise_progressions`) preserves every entry across repeated inserts rather than collapsing to "latest." Extend this file as new tables gain repository logic.

## Widget

Each screen under `features/*/presentation/` gets tests for the states that apply to it: loading, loaded, empty, error, offline, permission-denied, success, partial. `test/widget_test.dart` (implemented) covers the current shell: app launches to onboarding with no network reachable, and navigating to the home shell renders the bottom nav and the honest "No plan yet" empty state.

## Security — RLS

Not yet automated against a real Supabase project (needs one provisioned). Manually verified once against a scratch local Postgres running the actual migration file with a stubbed `auth` schema and two simulated users — see [SECURITY.md](SECURITY.md) for the exact queries and results. Once a real Supabase project exists, this becomes a `supabase test db` (pgTAP) suite that runs in CI on every migration change, asserting:
- User A cannot `SELECT`/`UPDATE`/`DELETE` User B's rows on any owner-scoped table.
- User A cannot `INSERT` a row claiming `user_id = <User B>`.
- Reference tables (`exercises`, `foods`, `achievements`, `challenges`) are readable by any authenticated user and writable by none.

## Integration — offline-first scenario (product brief §47)

Blocked on feature code that doesn't exist yet (onboarding, workout execution, check-ins) and a provisioned Supabase project. Scheduled for phase 15 hardening once those land:

1. Fresh install, airplane mode on, complete onboarding, create + complete a workout, log a set, log weight, log a meal, complete a check-in, view progress, kill the app, relaunch, confirm everything is still there.
2. Reconnect, let the outbox drain, confirm the Supabase rows match with **no duplicates** (the event_id idempotency check from §Security, exercised for real instead of on a scratch DB).
3. Kill the app mid-drain (simulate a crash during `SyncEngine.drainQueue()`), relaunch, confirm `recoverInterrupted()` requeues the stuck entry and it completes on the next drain instead of being lost or duplicated.
4. Multi-day offline: advance device time / stay offline across several simulated days of usage, then reconnect and verify the full backlog syncs correctly in order.

## What "done" means for a phase

A phase is not marked complete in [ARCHITECTURE.md](ARCHITECTURE.md) §12 until: `flutter analyze` is clean, its new code has the unit/widget tests above, and it has been exercised on a real simulator/device screenshot-verified — not just compiled.
