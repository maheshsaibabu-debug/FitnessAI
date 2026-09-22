import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/application/dashboard_providers.dart';
import '../application/workout_execution_controller.dart';
import '../application/workout_execution_state.dart';
import 'widgets/exercise_animation_view.dart';
import 'widgets/exercise_detail_card.dart';
import 'widgets/rpe_selector.dart';

StickFigureSex _stickFigureSexFrom(String? sex) => switch (sex) {
      'male' => StickFigureSex.male,
      'female' => StickFigureSex.female,
      _ => StickFigureSex.other,
    };

/// The guided, set-by-set workout session (product spec §20). Every
/// number shown here — target, previous performance, the "next time"
/// recommendation — comes from a real local write or a real engine call,
/// not a placeholder.
class WorkoutExecutionScreen extends ConsumerWidget {
  const WorkoutExecutionScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final execution = ref.watch(workoutExecutionControllerProvider(workoutId));

    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: SafeArea(
        child: execution.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not start this workout: $e'),
          )),
          data: (state) {
            if (state.isFinished) {
              return _FeelingPrompt(workoutId: workoutId);
            }
            if (state.isResting) {
              return _RestView(workoutId: workoutId, state: state);
            }
            return _SetLoggingView(
              key: ValueKey('${state.exerciseIndex}-${state.setIndex}'),
              workoutId: workoutId,
              state: state,
            );
          },
        ),
      ),
    );
  }
}

class _SetLoggingView extends ConsumerStatefulWidget {
  const _SetLoggingView({super.key, required this.workoutId, required this.state});

  final String workoutId;
  final WorkoutExecutionState state;

  @override
  ConsumerState<_SetLoggingView> createState() => _SetLoggingViewState();
}

class _SetLoggingViewState extends ConsumerState<_SetLoggingView> {
  late int _repsValue;
  int? _rpe;

  @override
  void initState() {
    super.initState();
    _repsValue = widget.state.currentExercise?.workoutExercise.targetReps ?? 0;
  }

  Future<void> _logSet(String outcome) async {
    final controller = ref.read(workoutExecutionControllerProvider(widget.workoutId).notifier);
    final isDurationBased = widget.state.currentExercise?.workoutExercise.targetReps == null;
    await controller.logCurrentSet(
      actualReps: isDurationBased ? null : _repsValue,
      rpe: _rpe,
      outcome: outcome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.state.currentExercise;
    if (exercise == null) return const SizedBox.shrink();
    final we = exercise.workoutExercise;
    final isDurationBased = we.targetReps == null;
    final setNumber = widget.state.setIndex + 1;
    final totalSets = widget.state.totalSetsInCurrentExercise;
    final profile = ref.watch(activeProfileProvider).valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercise ${widget.state.exerciseIndex + 1} of ${widget.state.exercises.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          ExerciseDetailCard(
            index: widget.state.exerciseIndex + 1,
            exercise: exercise.exercise,
            sex: _stickFigureSexFrom(profile?.sex),
            targetSets: we.targetSets ?? 1,
            targetReps: we.targetReps,
            targetDurationSeconds: we.targetDurationSeconds,
            restSeconds: we.restSeconds ?? 60,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Set $setNumber of $totalSets', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (isDurationBased)
                    Text(
                      'Target: ${we.targetDurationSeconds ?? 0}s',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  else ...[
                    Text('Target: ${we.targetReps} reps', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: _repsValue > 0 ? () => setState(() => _repsValue--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 96,
                          child: Column(
                            children: [
                              Text('$_repsValue', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700)),
                              Text('reps', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => setState(() => _repsValue++),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('RPE (optional)', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  RpeSelector(value: _rpe, onChanged: (v) => setState(() => _rpe = v)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _logSet('skipped'),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Skipped', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _logSet('reduced'),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Reduced', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => _logSet('completed'),
                  child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Completed', maxLines: 1)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestView extends ConsumerWidget {
  const _RestView({required this.workoutId, required this.state});

  final String workoutId;
  final WorkoutExecutionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.lastRecommendation != null) ...[
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${state.lastRecommendationExerciseName}: ${state.lastRecommendation!.rationale}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
          Text('Rest', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('${state.restSecondsRemaining}s', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () =>
                ref.read(workoutExecutionControllerProvider(workoutId).notifier).skipRest(),
            child: const Text('Skip rest'),
          ),
        ],
      ),
    );
  }
}

const _feelingOptions = [
  ('easy', 'Easy'),
  ('good', 'Good'),
  ('challenging', 'Challenging'),
  ('very_difficult', 'Very difficult'),
];

class _FeelingPrompt extends ConsumerWidget {
  const _FeelingPrompt({required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('How did that feel?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          for (final (value, label) in _feelingOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref
                        .read(workoutExecutionControllerProvider(workoutId).notifier)
                        .finish(feeling: value);
                    if (context.mounted) context.go('/home');
                  },
                  child: Text(label),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
