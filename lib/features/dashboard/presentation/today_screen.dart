import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../domain/workout_engine/workout_generation_engine.dart';
import '../../../shared/widgets/category_icon_badge.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../../tracking/application/tracking_providers.dart';
import '../application/dashboard_providers.dart';

const _skipReasons = [
  ('no_time', 'No time'),
  ('too_tired', 'Too tired'),
  ('busy', 'Busy'),
  ('sore', 'Sore'),
  ('no_equipment', 'No equipment'),
  ('not_motivated', 'Not motivated'),
  ('other', 'Other'),
];

/// "Today" — answers "what should I do right now?" (product spec §21,
/// §39). Every row shown here is real data (workout from the generated
/// plan, steps from StepsRepository) — nothing invented to fill out the
/// layout.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysWorkout = ref.watch(todaysWorkoutProvider);
    final todaysSteps = ref.watch(todaysStepsProvider);
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final goals = ref.watch(activeGoalsProvider).valueOrNull ?? const {};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const OfflineBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '${_greeting()}${profile != null ? ', ${profile.name}' : ''}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Small steps create big results.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Today's Plan", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 16),
                          todaysWorkout.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            ),
                            error: (e, st) => Text('Could not load today\'s plan: $e'),
                            data: (workout) => _WorkoutRow(workout: workout, goals: goals),
                          ),
                          const SizedBox(height: 14),
                          todaysSteps.when(
                            loading: () => const SizedBox.shrink(),
                            error: (e, st) => const SizedBox.shrink(),
                            data: (record) => _InfoRow(
                              icon: Icons.directions_walk,
                              categoryKey: 'steps',
                              label: 'Steps',
                              value: record == null
                                  ? 'Not logged yet'
                                  : '${record.steps}${record.target != null ? ' / ${record.target}' : ''}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  todaysWorkout.valueOrNull != null
                      ? _WorkoutActions(workout: todaysWorkout.value!)
                      : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.categoryKey, required this.label, required this.value, this.subtitle});

  final IconData icon;
  final String categoryKey;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryIconBadge(icon: icon, categoryKey: categoryKey, size: 40),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
        Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout, required this.goals});
  final Workout? workout;
  final Set<String> goals;

  @override
  Widget build(BuildContext context) {
    if (workout == null) {
      return _InfoRow(icon: Icons.self_improvement, categoryKey: 'rest', label: 'Rest day', value: 'Nothing scheduled');
    }
    return _InfoRow(
      icon: Icons.fitness_center,
      categoryKey: 'workout',
      label: workout!.title,
      value: '${workout!.estimatedMinutes ?? '—'} min',
      subtitle: workoutFocusSummary(workoutType: workout!.workoutType, goals: goals),
    );
  }
}

class _WorkoutActions extends ConsumerWidget {
  const _WorkoutActions({required this.workout});
  final Workout workout;

  bool get _isDone => workout.status == 'completed' || workout.status == 'skipped';

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What\'s stopping you?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (value, label) in _skipReasons)
                    ActionChip(label: Text(label), onPressed: () => Navigator.of(context).pop(value)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null) return;

    final profile = await ref.read(profileRepositoryProvider).activeProfileOnce();
    if (profile == null) return;
    await ref.read(workoutExecutionRepositoryProvider).completeWorkout(
          workoutId: workout.id,
          userId: profile.id,
          status: 'skipped',
          skipReasonCode: reason,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isDone) {
      return Text(
        workout.status == 'completed' ? 'Completed — nice work.' : 'Skipped for today.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _skip(context, ref),
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => context.push('/workout/${workout.id}'),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
          ),
        ),
      ],
    );
  }
}
