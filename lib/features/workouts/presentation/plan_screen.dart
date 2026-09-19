import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/category_icon_badge.dart';
import '../../dashboard/application/dashboard_providers.dart';

const Map<String, IconData> _workoutTypeIcons = {
  'strength_full_body': Icons.fitness_center,
  'strength_upper': Icons.fitness_center,
  'strength_lower': Icons.fitness_center,
  'push': Icons.fitness_center,
  'pull': Icons.fitness_center,
  'legs': Icons.fitness_center,
  'hiit': Icons.bolt,
  'cardio': Icons.directions_run,
};

/// Lists the generated plan's upcoming workouts. Editing/regenerating the
/// plan, and the adaptive re-planning from actual adherence, are later
/// phases (6/10 already provide the engines; the UI to drive them from
/// here is not yet wired up) — this screen honestly shows what
/// [WorkoutGenerationEngine] produced at onboarding, nothing invented.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcoming = ref.watch(upcomingWorkoutsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan')),
      body: upcoming.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Could not load your plan: $e')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No workouts scheduled yet. Complete onboarding to generate your first week.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final workout = workouts[index];
              final isDone = workout.status == 'completed' || workout.status == 'skipped';
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: isDone ? null : () => context.push('/workout/${workout.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CategoryIconBadge(
                          icon: _workoutTypeIcons[workout.workoutType] ?? Icons.fitness_center,
                          categoryKey: workout.workoutType,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(workout.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat.MMMEd().format(workout.scheduledDate)} · ${workout.estimatedMinutes ?? '—'} min',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          workout.status,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
