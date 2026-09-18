# Security

## Authentication

Supabase Auth issues the session. The client is configured via `publishableKey` (Supabase's current non-deprecated auth parameter name for what was previously called the anon key) — never a service-role key, which must never ship in the client binary or be committed anywhere in this repo.

## Local secrets

Anything sensitive that must persist on-device (auth/session material) goes through `lib/core/security/secure_session_store.dart`, backed by `flutter_secure_storage` — Keychain on iOS, `EncryptedSharedPreferences` on Android. Nothing sensitive is written to plain `SharedPreferences` or an unencrypted file.

## Row Level Security

Every user-owned table in `supabase/migrations/00000000000001_init.sql` has `alter table ... enable row level security` plus an owner policy restricting `select/insert/update/delete` to `user_id = auth.uid()` (or `auth_user_id` for `user_profiles`). `workout_exercises`/`workout_sets`, which have no `user_id` column of their own, are scoped by an `exists` join up to the owning `workouts` row instead. Reference tables (`exercises`, `foods`, `achievements`, `challenges`) are read-only to any authenticated user and writable by no one from the client.

**Verified**, not just written: the migration was applied to a scratch local Postgres instance with a stubbed `auth` schema, and exercised with two simulated users (via `set app.current_user_id` standing in for `auth.uid()`):

- User B querying `weight_logs`/`user_profiles` filtered to User A's id got zero rows back.
- User B's `UPDATE` targeting User A's row by id affected zero rows.
- User B's `INSERT` claiming `user_id = <User A>` was rejected: `ERROR: new row violates row-level security policy`.
- A retried `upsert(..., onConflict: 'event_id')` for the same `event_id` produced exactly one row (idempotent sync — see [SYNC_CONFLICTS.md](SYNC_CONFLICTS.md)).

This is the same pattern the product brief §43 asks for as an ongoing test; it should be re-run against the real Supabase project (via `supabase test db` or an equivalent pgTAP/seeded-user suite) once one exists, not just the scratch instance used during development.

## No service-role key in the client

Nothing in `lib/` references a service-role key. Privileged operations (seeding reference data, admin tooling) belong in Edge Functions or the Supabase dashboard/CLI, never in the Flutter app.

## Least privilege

The `authenticated` Postgres role only has the grants RLS then narrows per-row — it is not given superuser or bypass-RLS privileges. Anonymous (unauthenticated) access is not granted on any user-data table.
