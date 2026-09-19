# Health Integration (Steps)

Product spec §22. Scope for this phase: step count only, read-only. The app never writes to HealthKit/Health Connect.

## Architecture

```
health plugin (HealthKit on iOS / Health Connect on Android)
  -> HealthRepository        (lib/data/local/health_repository.dart)
  -> StepsRepository         (lib/data/repositories/steps_repository.dart)  -> StepRecords table
  -> HealthConnectionController (lib/features/tracking/application/tracking_providers.dart)
  -> Track screen             (lib/features/tracking/presentation/track_screen.dart)
```

`HealthRepository` is the only place that imports `package:health`. Every method catches `MissingPluginException` and `PlatformException` and returns `null`/a `HealthPermissionStatus.unavailable` rather than throwing — a missing plugin registration, a denied permission, or a platform with no Health data at all must never crash a screen or block the rest of the app, per the offline-first rule.

## Permission model

`HealthPermissionStatus` is `granted | denied | unavailable`:

- **unavailable** — plugin not registered for this platform/build, or the underlying health store isn't present (e.g. `isHealthDataAvailable() == false`).
- **denied** — the user was asked and said no (Android can report this definitively; see the HealthKit caveat below).
- **granted** — either confirmed granted, or (iOS only) undetermined because Apple's privacy model refuses to disclose read-grant status — treated as "attempt the read and let the result speak for itself" rather than blocking the UI on a status HealthKit won't reveal.

The Track screen's `_ConnectionRow` renders one of three states off this enum: a "Connect Health" button (unavailable), an explanatory message with no button spam (denied — the manual entry field right below is the actual path forward), or a "Sync from Health" button (granted).

## Manual entry is not a fallback bolted on afterward

Every state of `_StepsCard` shows the manual-entry field, unconditionally. The product brief is explicit that health integration is best-effort; a user who never grants permission, or whose OS has no Health data at all, still has a fully working steps feature — just one they operate by typing a number, exactly as they'd expect from an offline-first app. Manual entries write with `source: 'manual'` to the same `StepRecords` row as an automatic sync would, distinguished only by that column.

## Local upsert, not append

Unlike most tables in this schema, a day's step count is **upserted** (one row per `(user_id, date)`, whichever source wrote most recently wins), not appended — see [SYNC_CONFLICTS.md](SYNC_CONFLICTS.md). `StepsRepository.upsertSteps` owns this by querying for an existing row before deciding insert vs. update, since Drift's local schema doesn't have a matching unique index in the Drift table (the uniqueness is enforced in code here, and separately as a real Postgres `unique(user_id, date)` constraint server-side once sync exists).

## Platform configuration

- **iOS**: `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` in `ios/Runner/Info.plist`; `ios/Runner/Runner.entitlements` declares `com.apple.developer.healthkit`, wired into all three build configs via `CODE_SIGN_ENTITLEMENTS`. **Known gap**: actually running on a real device additionally requires the HealthKit capability to be present on the provisioning profile, which needs a real Apple Developer Program team — out of scope for this local scaffolding and something whoever owns distribution will need to enable in App Store Connect / Xcode's Signing & Capabilities before a device build.
- **Android**: `android.permission.health.READ_STEPS` plus a `<queries>` entry for the Health Connect package (`com.google.android.apps.healthdata`) in `AndroidManifest.xml`; `minSdk` is 26 (Health Connect's floor), set in `android/app/build.gradle.kts`.

## What's verified vs. what isn't

**Verified**: the manual-entry path end-to-end (widget → `StepsRepository.upsertSteps` → `StepRecords` row → the same row read back by `todaysStepsProvider`), and that `HealthRepository`'s methods degrade to `null`/`unavailable` instead of throwing when the plugin can't do anything (exercised by unit test against a fake/absent platform channel).

**Not verified live**: actual HealthKit/Health Connect data retrieval. iOS Simulator's HealthKit store is typically empty with no way to seed step data from this environment, and Health Connect requires the Health Connect app installed on the emulator/device, which this dev environment doesn't have. This is a real, disclosed limitation — not a claim that live sync was tested and works. It should be verified on a physical device (or a Simulator with Health app data manually added) before this feature ships.
