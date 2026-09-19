import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../domain/fitness_engine/fitness_assessment_engine.dart';
import '../../domain/workout_engine/workout_generation_engine.dart';
import '../local/exercise_library_seeder.dart';

const _uuid = Uuid();

/// Bridges WorkoutGenerationEngine's pure output to the local schema.
class WorkoutPlanRepository {
  WorkoutPlanRepository(this._db, this._exerciseLibrarySeeder);

  final AppDatabase _db;
  final ExerciseLibrarySeeder _exerciseLibrarySeeder;

  Future<String> generateAndPersistFirstWeek({
    required String userId,
    required TrainingProfile trainingProfile,
    required DateTime startDate,
  }) async {
    final generated = await _generateWeek(trainingProfile);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);

    return _db.transaction(() => _insertGeneratedWeek(
          userId: userId,
          planName: 'Week 1',
          generated: generated,
          startDay: startDay,
        ));
  }

  /// Replaces the not-yet-done portion of the active plan with a fresh
  /// week from the (possibly since-improved) generation engine — e.g.
  /// after a fix to how session length or goal-matching is computed.
  /// Workouts already completed, skipped, or in progress are untouched;
  /// only 'scheduled' workouts from [from] onward are cleared to make
  /// room, so history never disappears and an active session is never
  /// pulled out from under the user.
  Future<String> regenerateUpcomingPlan({
    required String userId,
    required TrainingProfile trainingProfile,
    required DateTime from,
  }) async {
    final generated = await _generateWeek(trainingProfile);
    final today = DateTime(from.year, from.month, from.day);

    return _db.transaction(() async {
      final todaysWorkout =
          await (_db.select(_db.workouts)..where((w) => w.userId.equals(userId) & w.scheduledDate.equals(today)))
              .getSingleOrNull();
      final startDay =
          (todaysWorkout != null && todaysWorkout.status != 'scheduled') ? today.add(const Duration(days: 1)) : today;

      final staleWorkouts = await (_db.select(_db.workouts)
            ..where((w) =>
                w.userId.equals(userId) & w.scheduledDate.isBiggerOrEqualValue(startDay) & w.status.equals('scheduled')))
          .get();
      for (final stale in staleWorkouts) {
        final staleExercises =
            await (_db.select(_db.workoutExercises)..where((e) => e.workoutId.equals(stale.id))).get();
        for (final ex in staleExercises) {
          await (_db.delete(_db.workoutSets)..where((s) => s.workoutExerciseId.equals(ex.id))).go();
        }
        await (_db.delete(_db.workoutExercises)..where((e) => e.workoutId.equals(stale.id))).go();
        await (_db.delete(_db.workouts)..where((w) => w.id.equals(stale.id))).go();
      }

      await (_db.update(_db.workoutPlans)..where((p) => p.userId.equals(userId) & p.isActive.equals(true)))
          .write(const WorkoutPlansCompanion(isActive: Value(false)));

      return _insertGeneratedWeek(userId: userId, planName: 'Refreshed plan', generated: generated, startDay: startDay);
    });
  }

  Future<GeneratedPlan> _generateWeek(TrainingProfile trainingProfile) async {
    await _exerciseLibrarySeeder.seedIfEmpty();
    final library = await _exerciseLibrarySeeder.loadSummaries();
    return const WorkoutGenerationEngine().generateWeek(profile: trainingProfile, exerciseLibrary: library);
  }

  Future<String> _insertGeneratedWeek({
    required String userId,
    required String planName,
    required GeneratedPlan generated,
    required DateTime startDay,
  }) async {
    final now = DateTime.now().toUtc();
    final planId = _uuid.v4();

    await _db.into(_db.workoutPlans).insert(WorkoutPlansCompanion.insert(
          id: planId,
          userId: userId,
          name: planName,
          isActive: const Value(true),
          startDate: startDay,
          createdAt: now,
          updatedAt: now,
        ));

    for (final workout in generated.workouts) {
      final workoutId = _uuid.v4();
      await _db.into(_db.workouts).insert(WorkoutsCompanion.insert(
            id: workoutId,
            planId: Value(planId),
            userId: userId,
            title: workout.title,
            workoutType: workout.workoutType,
            scheduledDate: startDay.add(Duration(days: workout.dayOffset)),
            estimatedMinutes: Value(workout.estimatedMinutes),
            createdAt: now,
            updatedAt: now,
          ));

      for (final exercise in workout.exercises) {
        final workoutExerciseId = _uuid.v4();
        await _db.into(_db.workoutExercises).insert(WorkoutExercisesCompanion.insert(
              id: workoutExerciseId,
              workoutId: workoutId,
              exerciseId: exercise.exerciseId,
              orderIndex: exercise.orderIndex,
              targetSets: Value(exercise.targetSets),
              targetReps: Value(exercise.targetReps),
              targetDurationSeconds: Value(exercise.targetDurationSeconds),
              restSeconds: Value(exercise.restSeconds),
            ));

        // Pre-create one WorkoutSets row per target set so the execution
        // screen has something to fill in rather than materializing sets
        // on the fly — the plan already decided how many sets there are.
        final setCount = exercise.targetSets ?? 1;
        for (var setIndex = 0; setIndex < setCount; setIndex++) {
          await _db.into(_db.workoutSets).insert(WorkoutSetsCompanion.insert(
                id: _uuid.v4(),
                workoutExerciseId: workoutExerciseId,
                setIndex: setIndex,
                targetReps: Value(exercise.targetReps),
                createdAt: now,
              ));
        }
      }
    }

    return planId;
  }

  Stream<List<Workout>> watchUpcomingWorkouts(String userId, {required DateTime from}) {
    final fromDay = DateTime(from.year, from.month, from.day);
    return (_db.select(_db.workouts)
          ..where((w) => w.userId.equals(userId) & w.scheduledDate.isBiggerOrEqualValue(fromDay))
          ..orderBy([(w) => OrderingTerm.asc(w.scheduledDate)]))
        .watch();
  }

  Future<Workout?> todaysWorkout(String userId, {required DateTime today}) async {
    final day = DateTime(today.year, today.month, today.day);
    return (_db.select(_db.workouts)
          ..where((w) => w.userId.equals(userId) & w.scheduledDate.equals(day)))
        .getSingleOrNull();
  }

  Stream<Workout?> watchTodaysWorkout(String userId, {required DateTime today}) {
    final day = DateTime(today.year, today.month, today.day);
    return (_db.select(_db.workouts)
          ..where((w) => w.userId.equals(userId) & w.scheduledDate.equals(day)))
        .watchSingleOrNull();
  }

  Stream<List<WorkoutExercise>> watchExercisesFor(String workoutId) {
    return (_db.select(_db.workoutExercises)
          ..where((e) => e.workoutId.equals(workoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .watch();
  }

  /// Workouts scheduled from [days] days ago through today — a bounded
  /// adherence window (see docs/AI_ARCHITECTURE.md's FitnessContextResolver)
  /// rather than the full history, so the coach's context stays small and
  /// predictable regardless of how long the user has used the app.
  Future<List<Workout>> recentWorkouts(String userId, {int days = 14}) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final fromDay = todayDay.subtract(Duration(days: days));
    return (_db.select(_db.workouts)
          ..where((w) =>
              w.userId.equals(userId) &
              w.scheduledDate.isBiggerOrEqualValue(fromDay) &
              w.scheduledDate.isSmallerOrEqualValue(todayDay))
          ..orderBy([(w) => OrderingTerm.desc(w.scheduledDate)]))
        .get();
  }

  Future<Workout?> nextUpcomingWorkout(String userId) {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return (_db.select(_db.workouts)
          ..where((w) =>
              w.userId.equals(userId) & w.scheduledDate.isBiggerOrEqualValue(todayDay) & w.status.equals('scheduled'))
          ..orderBy([(w) => OrderingTerm.asc(w.scheduledDate)])
          ..limit(1))
        .getSingleOrNull();
  }
}

/// Maps the profile's persisted fitness level string back to the engine's
/// enum — the one conversion shared by every screen that needs to
/// regenerate or extend a plan from a saved profile.
FitnessLevel fitnessLevelFromString(String? value) => switch (value) {
      'advanced' => FitnessLevel.advanced,
      'intermediate' => FitnessLevel.intermediate,
      _ => FitnessLevel.beginner,
    };
