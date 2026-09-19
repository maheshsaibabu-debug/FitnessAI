import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

const _uuid = Uuid();

/// One exercise within an in-progress workout, joined with its exercise
/// metadata and pre-created sets — the shape the execution screen
/// actually needs, assembled once when a session starts rather than
/// streamed (a live workout session is controller-owned state, not a
/// reactive query — see WorkoutExecutionController).
class ExecutionExercise {
  const ExecutionExercise({required this.workoutExercise, required this.exercise, required this.sets});

  final WorkoutExercise workoutExercise;
  final Exercise exercise;
  final List<WorkoutSet> sets;

  ExecutionExercise copyWithSets(List<WorkoutSet> sets) =>
      ExecutionExercise(workoutExercise: workoutExercise, exercise: exercise, sets: sets);
}

/// Writes from an active workout session: set-by-set logging, the
/// append-only performance history, and the final completion record.
class WorkoutExecutionRepository {
  WorkoutExecutionRepository(this._db);

  final AppDatabase _db;

  Future<Workout> workoutById(String workoutId) {
    return (_db.select(_db.workouts)..where((w) => w.id.equals(workoutId))).getSingle();
  }

  Future<List<ExecutionExercise>> loadExercises(String workoutId) async {
    final workoutExercises = await (_db.select(_db.workoutExercises)
          ..where((e) => e.workoutId.equals(workoutId))
          ..orderBy([(e) => OrderingTerm.asc(e.orderIndex)]))
        .get();

    final result = <ExecutionExercise>[];
    for (final we in workoutExercises) {
      final exercise =
          await (_db.select(_db.exercises)..where((e) => e.id.equals(we.exerciseId))).getSingle();
      final sets = await (_db.select(_db.workoutSets)
            ..where((s) => s.workoutExerciseId.equals(we.id))
            ..orderBy([(s) => OrderingTerm.asc(s.setIndex)]))
          .get();
      result.add(ExecutionExercise(workoutExercise: we, exercise: exercise, sets: sets));
    }
    return result;
  }

  /// Marks the workout as actively being done — a lightweight local
  /// status flip, not the final completion event.
  Future<void> markInProgress(String workoutId) {
    return (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(status: const Value('in_progress'), updatedAt: Value(DateTime.now().toUtc())),
    );
  }

  Future<void> logSet({
    required String setId,
    int? actualReps,
    double? actualWeightKg,
    int? rpe,
    required String outcome, // completed|reduced|skipped
  }) {
    return (_db.update(_db.workoutSets)..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        actualReps: Value(actualReps),
        actualWeightKg: Value(actualWeightKg),
        rpe: Value(rpe),
        outcome: Value(outcome),
        eventId: Value(_uuid.v4()),
        completedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// The append-only performance stream WorkoutProgressionEngine and
  /// future plan generations read from — see docs/FITNESS_ENGINE.md.
  Future<void> recordExerciseProgression({
    required String userId,
    required String exerciseId,
    required String metricType,
    required double value,
    int? rpe,
  }) {
    final now = DateTime.now().toUtc();
    return _db.into(_db.exerciseProgressions).insert(ExerciseProgressionsCompanion.insert(
          id: _uuid.v4(),
          userId: userId,
          exerciseId: exerciseId,
          recordedAt: now,
          metricType: metricType,
          value: value,
          rpe: Value(rpe),
          eventId: _uuid.v4(),
          createdAt: now,
        ));
  }

  Future<void> completeWorkout({
    required String workoutId,
    required String userId,
    required String status, // completed|partial|skipped|couldnt_complete
    String? feeling,
    String? skipReasonCode,
    int? durationSeconds,
  }) async {
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _db.into(_db.workoutCompletions).insert(WorkoutCompletionsCompanion.insert(
            id: _uuid.v4(),
            workoutId: workoutId,
            userId: userId,
            status: status,
            skipReasonCode: Value(skipReasonCode),
            feeling: Value(feeling),
            durationSeconds: Value(durationSeconds),
            eventId: _uuid.v4(),
            completedAt: now,
            createdAt: now,
          ));

      await (_db.update(_db.workouts)..where((w) => w.id.equals(workoutId))).write(
        WorkoutsCompanion(status: Value(status), updatedAt: Value(now)),
      );
    });
  }
}
