import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/workout_execution_repository.dart';

part 'workout_preview_provider.g.dart';

class WorkoutPreview {
  const WorkoutPreview({required this.workout, required this.exercises});
  final Workout workout;
  final List<ExecutionExercise> exercises;
}

/// Read-only view of a workout's exercise list — deliberately separate
/// from [WorkoutExecutionController], which flips the workout to
/// 'in_progress' the moment it's built. Looking at what a day contains
/// shouldn't count as starting it.
@riverpod
Future<WorkoutPreview> workoutPreview(Ref ref, String workoutId) async {
  final repo = ref.watch(workoutExecutionRepositoryProvider);
  final workout = await repo.workoutById(workoutId);
  final exercises = await repo.loadExercises(workoutId);
  return WorkoutPreview(workout: workout, exercises: exercises);
}
