# Fitness Engines

The nine deterministic engines from the product brief §12, all pure Dart (`lib/domain/`) — no Flutter widget, no network client, no LLM call anywhere in this layer. Every one is unit-tested directly against plain inputs/outputs; none of them need a running app or a database to verify.

| Engine | File | What it does |
|---|---|---|
| WorkoutProgressionEngine | `progression_engine/workout_progression_engine.dart` | Turns "target vs. actual reps/weight + RPE" into a next-session recommendation (increase/hold/decrease). Verified against the product spec's own two worked examples. |
| NutritionCalculationEngine | `nutrition_engine/nutrition_calculation_engine.dart` | Mifflin-St Jeor BMR → activity-adjusted TDEE → goal-adjusted calorie target with a hard 1200kcal safety floor → protein/carb/fat split. |
| StreakEngine | `streak_engine/streak_engine.dart` | Current + longest streak from a set of "this happened" dates; tolerant of "today hasn't happened yet" so a streak doesn't zero out the instant the clock rolls over. |
| FitnessAssessmentEngine | `fitness_engine/fitness_assessment_engine.dart` | Classifies a baseline self-test (push-ups/squats/pull-ups/plank) into beginner/intermediate/advanced per movement and overall (weakest-link, not average). |
| AdaptivePlanEngine | `adaptive_engine/adaptive_plan_engine.dart` | Last week's planned-vs-actual session counts → next week's targets. Verified against the spec's example (3 strength kept, 2 HIIT → 1 shorter HIIT after being fully skipped); compounds the reduction on repeated low-adherence weeks. |
| MotivationEngine | `motivation_engine/motivation_engine.dart` | Deterministic coaching copy for moments (morning plan ready, mid-week progress, weekly celebration, comeback, streak-at-risk). Checked against a banned-language list — no guilt or shame framing, matching the spec's explicit rule. |
| ProgressAnalysisEngine | `progress_engine/progress_analysis_engine.dart` | Linear-regression weight trend (direction + kg/week rate) so a single noisy day doesn't flip the read; adherence-rate helper. |
| AchievementEngine | `progress_engine/achievement_engine.dart` | Closed catalog of achievement rules; diffs current stats against already-unlocked keys to return only newly-earned ones. |
| WorkoutGenerationEngine | `workout_engine/workout_generation_engine.dart` | Builds a week's workout split (full-body / upper-lower / push-pull-legs, depending on days available) and selects exercises from the bundled library by movement pattern, equipment owned, and fitness level. |

## How WorkoutGenerationEngine picks exercises

1. Days/week decides the split: ≤3 days → all full-body; 4 days → upper/lower alternating; 5+ days → push/pull/legs rotation, with the last day swapped for HIIT if the user's goal includes fat loss/endurance/cardio.
2. Each workout type maps to a list of desired movement patterns (e.g. full-body wants push, pull, legs, core).
3. For each pattern, candidates are filtered to exercises whose required equipment is a subset of what the user has (plus bodyweight, always available) and whose difficulty is at or below the user's fitness level, then the first match in a stable sort order is picked — deterministic, so the same profile always generates the same plan.
4. Sets/reps/rest are assigned from a fixed table keyed by fitness level (beginner: 2×12 @ 60s rest, intermediate: 3×10 @ 75s, advanced: 4×8 @ 90s); HIIT workouts get duration-based targets instead of reps.

This is deliberately simple — good enough to produce a sensible, equipment-respecting, level-appropriate first plan. It is not a sports-science optimizer, and isn't trying to be; the adaptive engine (§ above) is what corrects a plan that turns out to be wrong for a given person, from real adherence data, rather than trying to get the first guess perfect.

## Wiring: onboarding → engines → persisted plan

`lib/features/onboarding/application/onboarding_controller.dart`'s `submit()` is the one place these engines currently get called end-to-end:

1. `ProfileRepository.completeOnboarding` runs `FitnessAssessmentEngine` (if baseline data was entered — it overrides the self-reported level) and `NutritionCalculationEngine`, then writes the profile/goal/baseline/weight-log/nutrition-goal rows in one transaction.
2. `WorkoutPlanRepository.generateAndPersistFirstWeek` seeds the bundled exercise library on first run (`ExerciseLibrarySeeder`), runs `WorkoutGenerationEngine`, and persists the resulting plan/workouts/workout-exercises.

Verified live on iOS Simulator (onboarding → Today tab shows the real generated workout; Plan tab shows the full week) and by `test/integration/onboarding_flow_integration_test.dart`, which drives the same controller against an in-memory database and asserts on the resulting rows.

## Not yet wired

`AdaptivePlanEngine`, `WorkoutProgressionEngine`, `StreakEngine`, `MotivationEngine`, `ProgressAnalysisEngine`, and `AchievementEngine` are implemented and unit-tested but not yet called from any UI flow — that happens in phases 7 (workout execution, for progression), 10 (accountability, for adaptive planning and streaks), 12 (progress screen), and 13 (motivation/notifications).
