import 'package:drift/native.dart';
import 'package:fitness_companion/core/database/app_database.dart';
import 'package:fitness_companion/core/database/database_provider.dart';
import 'package:fitness_companion/data/repositories/repository_providers.dart';
import 'package:fitness_companion/features/onboarding/application/onboarding_controller.dart';
import 'package:fitness_companion/features/workouts/application/workout_execution_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives a full workout session against a real (in-memory) database:
/// generate a plan via onboarding, start today's workout, log every set,
/// and confirm the resulting rows — set outcomes, the append-only
/// exercise-progression stream, the workout completion, and the workout's
/// final status — are exactly what a real session should produce.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [appDatabaseProvider.overrideWithValue(db)]);
  });

  tearDown(() async {
    container.dispose();
    // Must be awaited: closing an in-memory sqlite3/FFI connection is
    // async, and package:test does not wait for a bare statement inside
    // a block-bodied callback. An unawaited close() here would let the
    // next test's setUp open its own NativeDatabase.memory() while this
    // one is still being torn down.
    await db.close();
  });

  testWidgets('logging every set and finishing writes a real completion record', (tester) async {
    // Onboard a beginner, bodyweight-only, 3 days/week user so the plan
    // is small and deterministic (full-body x3, per WorkoutGenerationEngine).
    final onboarding = container.read(onboardingControllerProvider.notifier);
    onboarding.updateName('Grace');
    onboarding.updateSex('female');
    onboarding.updateDateOfBirth(DateTime(1992, 5, 1));
    onboarding.updateHeightCm(170);
    onboarding.updateWeightKg(65);
    onboarding.toggleGoal('general');
    onboarding.updateLevelAndLocation(fitnessLevel: 'beginner', trainingLocation: 'home');
    onboarding.toggleEquipment('none');
    onboarding.updateAvailability(daysPerWeek: 3, minutesPerSession: 30);
    await onboarding.submit();

    final profile = await container.read(profileRepositoryProvider).activeProfileOnce();
    final workouts = await db.select(db.workouts).get();
    final todaysWorkoutRow = workouts.first; // plan starts today (dayOffset 0)

    final executionNotifier =
        container.read(workoutExecutionControllerProvider(todaysWorkoutRow.id).notifier);

    // Wait for the async build() to finish loading the session.
    await container.read(workoutExecutionControllerProvider(todaysWorkoutRow.id).future);

    var state = container.read(workoutExecutionControllerProvider(todaysWorkoutRow.id)).value!;
    expect(state.exercises, isNotEmpty);
    expect(state.userId, profile!.id);

    // The workout should already be flipped to in_progress once a session starts.
    final inProgress = await (db.select(db.workouts)..where((w) => w.id.equals(todaysWorkoutRow.id)))
        .getSingle();
    expect(inProgress.status, 'in_progress');

    // Log every set of every exercise as "completed" with a comfortable RPE
    // so the deterministic progression engine recommends an increase.
    while (!state.isFinished) {
      final targetReps = state.currentExercise?.workoutExercise.targetReps;
      await executionNotifier.logCurrentSet(
        actualReps: targetReps,
        rpe: 6,
        outcome: 'completed',
      );
      state = container.read(workoutExecutionControllerProvider(todaysWorkoutRow.id)).value!;
      if (state.isResting) {
        executionNotifier.skipRest();
        state = container.read(workoutExecutionControllerProvider(todaysWorkoutRow.id)).value!;
      }
    }

    await executionNotifier.finish(feeling: 'good');

    // Every set belonging to *today's* workout actually persisted its
    // outcome — the plan covers the whole week, so other days' sets are
    // deliberately left untouched and must not be swept up by this check.
    final todaysWorkoutExerciseIds =
        state.exercises.map((e) => e.workoutExercise.id).toSet();
    final loggedSets = await db.select(db.workoutSets).get();
    final todaysSets =
        loggedSets.where((s) => todaysWorkoutExerciseIds.contains(s.workoutExerciseId)).toList();
    expect(todaysSets, isNotEmpty);
    expect(todaysSets.every((s) => s.outcome == 'completed'), isTrue);
    expect(todaysSets.every((s) => s.actualReps != null), isTrue);

    // One ExerciseProgressions row per exercise (append-only performance
    // stream) — reps-based exercises only, matching the engine's contract.
    final progressions = await db.select(db.exerciseProgressions).get();
    expect(progressions, isNotEmpty);
    for (final p in progressions) {
      expect(p.metricType, 'reps');
      expect(p.userId, profile.id);
    }

    // Workout completion recorded and idempotency-keyed.
    final completions = await db.select(db.workoutCompletions).get();
    expect(completions, hasLength(1));
    expect(completions.single.status, 'completed');
    expect(completions.single.feeling, 'good');
    expect(completions.single.eventId, isNotEmpty);

    // Workout row itself reflects the final status.
    final finishedWorkout =
        await (db.select(db.workouts)..where((w) => w.id.equals(todaysWorkoutRow.id))).getSingle();
    expect(finishedWorkout.status, 'completed');
  });

  testWidgets('skipping a workout records a reason and never touches sets', (tester) async {
    final onboarding = container.read(onboardingControllerProvider.notifier);
    onboarding.updateName('Sam');
    onboarding.updateSex('male');
    onboarding.updateDateOfBirth(DateTime(1990, 1, 1));
    onboarding.updateHeightCm(175);
    onboarding.updateWeightKg(80);
    onboarding.toggleGoal('general');
    onboarding.updateLevelAndLocation(fitnessLevel: 'beginner', trainingLocation: 'home');
    onboarding.toggleEquipment('none');
    onboarding.updateAvailability(daysPerWeek: 3, minutesPerSession: 30);
    await onboarding.submit();

    final profile = await container.read(profileRepositoryProvider).activeProfileOnce();
    final workouts = await db.select(db.workouts).get();
    final todaysWorkoutRow = workouts.first;

    await container.read(workoutExecutionRepositoryProvider).completeWorkout(
          workoutId: todaysWorkoutRow.id,
          userId: profile!.id,
          status: 'skipped',
          skipReasonCode: 'no_time',
        );

    final completions = await db.select(db.workoutCompletions).get();
    expect(completions.single.status, 'skipped');
    expect(completions.single.skipReasonCode, 'no_time');

    final sets = await db.select(db.workoutSets).get();
    expect(sets.every((s) => s.outcome == null), isTrue);
  });
}
