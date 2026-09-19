import '../../../core/database/app_database.dart';
import '../../../data/repositories/workout_execution_repository.dart';
import '../../../domain/progression_engine/workout_progression_engine.dart';

/// Live state for one in-progress workout session. Owned by the
/// controller, not streamed from Drift — an active session is
/// conversation-like (linear progression through sets with a rest
/// timer), not a reactive query.
class WorkoutExecutionState {
  const WorkoutExecutionState({
    required this.workoutId,
    required this.userId,
    required this.exercises,
    this.exerciseIndex = 0,
    this.setIndex = 0,
    this.restSecondsRemaining,
    this.isFinished = false,
    this.lastRecommendation,
    this.lastRecommendationExerciseName,
  });

  final String workoutId;
  final String userId;
  final List<ExecutionExercise> exercises;
  final int exerciseIndex;
  final int setIndex;
  final int? restSecondsRemaining;
  final bool isFinished;
  final ProgressionRecommendation? lastRecommendation;
  final String? lastRecommendationExerciseName;

  ExecutionExercise? get currentExercise =>
      exerciseIndex < exercises.length ? exercises[exerciseIndex] : null;

  WorkoutSet? get currentSet {
    final exercise = currentExercise;
    if (exercise == null || setIndex >= exercise.sets.length) return null;
    return exercise.sets[setIndex];
  }

  bool get isResting => restSecondsRemaining != null;

  int get totalSetsInCurrentExercise => currentExercise?.sets.length ?? 0;

  WorkoutExecutionState copyWith({
    List<ExecutionExercise>? exercises,
    int? exerciseIndex,
    int? setIndex,
    int? restSecondsRemaining,
    bool clearRest = false,
    bool? isFinished,
    ProgressionRecommendation? lastRecommendation,
    String? lastRecommendationExerciseName,
  }) {
    return WorkoutExecutionState(
      workoutId: workoutId,
      userId: userId,
      exercises: exercises ?? this.exercises,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      setIndex: setIndex ?? this.setIndex,
      restSecondsRemaining: clearRest ? null : (restSecondsRemaining ?? this.restSecondsRemaining),
      isFinished: isFinished ?? this.isFinished,
      lastRecommendation: lastRecommendation ?? this.lastRecommendation,
      lastRecommendationExerciseName: lastRecommendationExerciseName ?? this.lastRecommendationExerciseName,
    );
  }
}
