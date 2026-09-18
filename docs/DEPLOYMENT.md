# Deployment

## Environments

Three named environments (`lib/core/config/env.dart` -> `AppEnvironment`), selected by `APP_ENV` in `.env`: `development`, `staging`, `production`. Each points at its own Supabase project (separate URL/key pairs) — never share a Postgres instance between staging and production. `.env` is gitignored; `.env.example` documents the required keys with placeholders.

## CI (implemented)

`.github/workflows/ci.yml` runs on every push/PR to `main`: `flutter pub get`, codegen (`build_runner build`), `flutter analyze`, `flutter test`. This is the current full gate — no build/release automation exists yet.

## Not yet implemented

- Store builds (TestFlight / Play Internal Testing) and signing config.
- Supabase migration deployment automation (`supabase db push` against staging/production from CI).
- Release versioning/changelog process.

These land in phase 15 (hardening) once there's a real release candidate to ship, rather than being scaffolded ahead of having anything to deploy.
