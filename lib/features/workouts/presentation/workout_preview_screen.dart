import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/repository_providers.dart';
import '../../../data/repositories/workout_execution_repository.dart';
import '../../../domain/workout_engine/workout_generation_engine.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../application/workout_execution_controller.dart';
import '../application/workout_preview_provider.dart';

/// Shown before a workout starts: what the day actually contains, one
/// exercise at a time with its target sets/reps — so "Push Day" isn't a
/// surprise once you're already mid-session. Hevy/Strong-style workout
/// summary, not a new idea, just one this app was missing.
class WorkoutPreviewScreen extends ConsumerWidget {
  const WorkoutPreviewScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(workoutPreviewProvider(workoutId));
    final goals = ref.watch(activeGoalsProvider).valueOrNull ?? const {};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          if (preview.valueOrNull != null && preview.value!.workout.status != 'scheduled')
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Reset workout',
              onPressed: () => _confirmReset(context, ref, workoutId),
            ),
        ],
      ),
      body: SafeArea(
        child: preview.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load this workout: $e')),
          ),
          data: (data) {
            final workout = data.workout;
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(workout.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${workout.estimatedMinutes ?? '—'} min · ${workoutFocusSummary(workoutType: workout.workoutType, goals: goals)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      Text('${data.exercises.length} exercises', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      for (var i = 0; i < data.exercises.length; i++)
                        _ExerciseRow(index: i + 1, exercise: data.exercises[i]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: workout.status == 'completed'
                          ? null
                          : () => context.push('/workout/$workoutId/execute'),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(workout.status == 'completed' ? 'Completed' : 'Start Workout'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _confirmReset(BuildContext context, WidgetRef ref, String workoutId) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset this workout?'),
      content: const Text("Any sets you logged will be cleared and you'll start again from exercise 1."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reset')),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(workoutExecutionRepositoryProvider).resetWorkout(workoutId);
  ref.invalidate(workoutExecutionControllerProvider(workoutId));
  ref.invalidate(workoutPreviewProvider(workoutId));
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.exercise});

  final int index;
  final ExecutionExercise exercise;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final we = exercise.workoutExercise;
    final targetLabel = we.targetReps != null
        ? '${we.targetSets ?? 1} × ${we.targetReps} reps'
        : '${we.targetSets ?? 1} × ${we.targetDurationSeconds ?? 0}s';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('$index', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(exercise.exercise.name, style: Theme.of(context).textTheme.bodyLarge),
            ),
            Text(targetLabel, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
