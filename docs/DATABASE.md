# Database

Two schemas, kept in lockstep by hand (documented together, changed together):

- **Local**: `lib/core/database/tables/*.dart` (Drift/SQLite) — the operational source of truth on-device.
- **Cloud**: `supabase/migrations/*.sql` (Postgres) — sync target, multi-device backup, community/reference data.

## Table groups

| File | Tables | Notes |
|---|---|---|
| `profile_tables.dart` | `user_profiles`, `fitness_goals`, `fitness_baselines` | One local profile row = the signed-in user. |
| `exercise_tables.dart` | `exercises`, `exercise_progressions` | `exercises` is bundled read-only reference data (seeded from `assets/data/exercises.json`); `exercise_progressions` is an append-only performance stream. |
| `workout_tables.dart` | `workout_plans`, `workouts`, `workout_exercises`, `workout_sets`, `workout_completions` | `workout_completions` and completed `workout_sets` carry `event_id` for idempotent sync. |
| `health_tables.dart` | `step_records`, `cardio_sessions`, `hiit_sessions`, `weight_logs`, `body_composition_logs`, `measurement_logs` | `step_records` is an upserted daily total; everything else is an append-only time series. |
| `nutrition_tables.dart` | `nutrition_goals`, `foods`, `meals`, `meal_logs` | `foods` is a small bundled reference seed, not a full food database. |
| `accountability_tables.dart` | `daily_plans`, `daily_tasks`, `task_completions`, `coach_events`, `coach_insights`, `notifications`, `notification_preferences` | `task_completions` carries the skip-reason code that feeds the adaptive engine. |
| `progress_tables.dart` | `achievements`, `achievement_unlocks`, `personal_records` | |
| `social_tables.dart` | `challenges`, `challenge_participations` | `challenges` are cloud-authored reference rows, cached locally read-only. |
| `sync_tables.dart` | `sync_queue_entries`, `sync_metadata_entries` | The outbox. Never itself synced. |

## Conventions

- Primary keys are client-generated UUIDv4 `TEXT` columns (`package:uuid`), not autoincrement — so a row created offline already has its permanent id and never needs remapping after sync.
- `createdAt` / `updatedAt` are UTC `DateTime`. Mutable singletons also carry an integer `version` for deterministic conflict resolution.
- Anything the sync engine uploads carries a client-generated `eventId` (UUID) — this is what the server's `unique` constraint dedupes on. See [SYNC_CONFLICTS.md](SYNC_CONFLICTS.md) for the full per-entity policy.
- The Supabase schema adds `auth.users` foreign keys and RLS that Drift has no equivalent for; everything else is a direct structural mirror.

## Migrations

- Local: Drift `MigrationStrategy` in `app_database.dart`, additive only (`schemaVersion` bump + `onUpgrade` steps). No destructive migration ships against user data without an explicit backfill.
- Cloud: numbered files under `supabase/migrations/`, applied with `supabase db push` / `supabase migration up`.
