# Sync Conflict Resolution Policy

Every table that can be written from more than one device (or written offline then synced later) needs an explicit merge rule. "Last write wins" is the default failure mode of naive sync engines and it silently deletes data — so each entity below states the rule and why it's correct for that entity.

| Entity class | Examples | Rule | Rationale |
|---|---|---|---|
| Append-only event | `WorkoutCompletion`, `SetCompleted` (part of `WorkoutSet`), `TaskCompletion`, `PersonalRecord`, `CoachEvent` | Idempotent insert keyed by client-generated `event_id` (UUID). Server: `ON CONFLICT (event_id) DO NOTHING`. | These represent "a thing happened." A retried upload after a dropped connection must not create a second workout completion. Never updated, never merged — just deduplicated. |
| Time-series log | `WeightLog`, `BodyCompositionLog`, `MeasurementLog`, `StepRecord`, `MealLog` | Insert keyed by `(user_id, metric_type, recorded_at)`. Two entries at different timestamps both persist, even from different devices. | Two real measurements taken at different times are both true. Collapsing them to "latest" would delete a legitimate data point. |
| Mutable singleton | `UserProfile`, `NutritionGoal`, `NotificationPreference`, active `WorkoutPlan` pointer | Last-write-wins by `updated_at`; ties broken by a monotonic per-row `version` integer incremented on every local write. | These represent current state, not history — there is exactly one correct "current profile." A version counter avoids clock-skew ties resolving nondeterministically. |
| Historical performance stream | `ExerciseProgression`, `WorkoutSet` results | Append-only, never mutated in place; the "current" value is derived by querying the latest row, not by overwriting a field. | Preserves the full training history needed by the progression engine — overwriting would destroy the record the adaptive engine depends on. |
| Queue/local-only | `SyncQueue`, `SyncMetadata` | Never synced themselves — they are the mechanism, not the payload. | N/A |

## Deletes

Soft-delete only (`deleted_at` timestamp) for anything the user might want restored or that other rows reference (e.g. a `WorkoutExercise` referencing an `Exercise`). Hard deletes are reserved for local cache eviction of already-synced rows, never propagated as a delete event against user data without an explicit confirmation flow.

## Multi-device same-entity edits

If the same mutable singleton is edited offline on two devices before either syncs, the device that syncs second detects a server `version` newer than its local base version, and defers to server state for fields it did not itself change locally since its last known-good sync — implemented as a field-level merge for `UserProfile`/`NutritionGoal` rather than whole-row overwrite, so an offline height edit on phone A doesn't get clobbered by an offline goal edit on phone B.
