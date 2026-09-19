import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/workout_execution_repository.dart';
import '../../../domain/progression_engine/workout_progression_engine.dart';
import 'workout_execution_state.dart';

part 'workout_execution_controller.g.dart';

/// Drives one active workout session: loads the plan's pre-created sets,
/// records each logged set, runs a real rest-interval countdown between
/// sets, feeds completed-exercise performance into
/// WorkoutProgressionEngine for a "next time" recommendation, and writes
/// the final WorkoutCompletion. See docs/FITNESS_ENGINE.md for how this
/// connects to the deterministic engines.
@Riverpod(keepAlive: true)
class WorkoutExecutionController extends _$WorkoutExecutionController {
  Timer? _restTimer;
  DateTime? _startedAt;

  @override
  Future<WorkoutExecutionState> build(String workoutId) async {
    ref.onDispose(() => _restTimer?.cancel());

    final profile = await ref.watch(profileRepositoryProvider).activeProfileOnce();
    if (profile == null) {
      throw StateError('Cannot start a workout session without an onboarded profile.');
    }

    final repo = ref.watch(workoutExecutionRepositoryProvider);
    await repo.markInProgress(workoutId);
    final exercises = await repo.loadExercises(workoutId);

    _startedAt = DateTime.now();
    return WorkoutExecutionState(workoutId: workoutId, userId: profile.id, exercises: exercises);
  }

  /// Records the current set's outcome, advances to the next set (or the
  /// next exercise, or finishes the workout), and starts a rest timer
  /// when one applies.
  Future<void> logCurrentSet({int? actualReps, int? rpe, required String outcome}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final exercise = current.currentExercise;
    final set = current.currentSet;
    if (exercise == null || set == null) return;

    final repo = ref.read(workoutExecutionRepositoryProvider);
    await repo.logSet(setId: set.id, actualReps: actualReps, rpe: rpe, outcome: outcome);

    final updatedSet = set.copyWith(
      actualReps: Value(actualReps),
      rpe: Value(rpe),
      outcome: Value(outcome),
      completedAt: Value(DateTime.now().toUtc()),
    );
    final updatedSets = [...exercise.sets];
    updatedSets[current.setIndex] = updatedSet;
    final updatedExercise = exercise.copyWithSets(updatedSets);

    final isLastSetOfExercise = current.setIndex == exercise.sets.length - 1;
    ProgressionRecommendation? recommendation;
    String? recommendationExerciseName;
    if (isLastSetOfExercise) {
      recommendation = await _recordProgressionAndRecommend(current.userId, updatedExercise);
      recommendationExerciseName = recommendation == null ? null : exercise.exercise.name;
    }

    final updatedExercises = [...current.exercises];
    updatedExercises[current.exerciseIndex] = updatedExercise;

    final nextExerciseIndex = isLastSetOfExercise ? current.exerciseIndex + 1 : current.exerciseIndex;
    final nextSetIndex = isLastSetOfExercise ? 0 : current.setIndex + 1;
    final finished = nextExerciseIndex >= updatedExercises.length;

    final restSeconds =
        (!finished && outcome != 'skipped') ? exercise.workoutExercise.restSeconds : null;

    state = AsyncData(current.copyWith(
      exercises: updatedExercises,
      exerciseIndex: finished ? current.exerciseIndex : nextExerciseIndex,
      setIndex: finished ? current.setIndex : nextSetIndex,
      restSecondsRemaining: restSeconds,
      clearRest: restSeconds == null,
      isFinished: finished,
      lastRecommendation: recommendation,
      lastRecommendationExerciseName: recommendationExerciseName,
    ));

    if (restSeconds != null) _startRestTimer(restSeconds);
  }

  void skipRest() {
    _restTimer?.cancel();
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearRest: true));
  }

  Future<void> finish({required String feeling}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final repo = ref.read(workoutExecutionRepositoryProvider);
    final durationSeconds =
        _startedAt == null ? null : DateTime.now().difference(_startedAt!).inSeconds;

    await repo.completeWorkout(
      workoutId: current.workoutId,
      userId: current.userId,
      status: 'completed',
      feeling: feeling,
      durationSeconds: durationSeconds,
    );
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.valueOrNull;
      if (current == null || current.restSecondsRemaining == null) {
        timer.cancel();
        return;
      }
      final remaining = current.restSecondsRemaining! - 1;
      if (remaining <= 0) {
        timer.cancel();
        state = AsyncData(current.copyWith(clearRest: true));
      } else {
        state = AsyncData(current.copyWith(restSecondsRemaining: remaining));
      }
    });
  }

  /// Reps-based exercises only — HIIT/duration-based sets don't have a
  /// comparable "target vs. actual reps" signal for the progression
  /// engine to reason about.
  Future<ProgressionRecommendation?> _recordProgressionAndRecommend(
    String userId,
    ExecutionExercise exercise,
  ) async {
    final targetReps = exercise.workoutExercise.targetReps;
    if (targetReps == null) return null;

    final loggedSets = exercise.sets.where((s) => s.actualReps != null).toList();
    if (loggedSets.isEmpty) return null;

    final repo = ref.read(workoutExecutionRepositoryProvider);
    final actualValues = loggedSets.map((s) => s.actualReps!).toList();
    final average = actualValues.reduce((a, b) => a + b) / actualValues.length;

    await repo.recordExerciseProgression(
      userId: userId,
      exerciseId: exercise.exercise.id,
      metricType: 'reps',
      value: average,
      rpe: _averageRpe(loggedSets),
    );

    final rpes = loggedSets.map((s) => s.rpe).whereType<int>().toList();
    final effectiveRpe = rpes.isEmpty ? 7 : (rpes.reduce((a, b) => a + b) / rpes.length).round();

    return const WorkoutProgressionEngine().recommendNextReps(
      targetReps: targetReps,
      actualReps: actualValues,
      rpe: effectiveRpe,
    );
  }

  int? _averageRpe(List<WorkoutSet> loggedSets) {
    final rpes = loggedSets.map((s) => s.rpe).whereType<int>().toList();
    if (rpes.isEmpty) return null;
    return (rpes.reduce((a, b) => a + b) / rpes.length).round();
  }
}
