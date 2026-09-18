import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../dashboard/application/dashboard_providers.dart';

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
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final workout = workouts[index];
              return Card(
                child: ListTile(
                  title: Text(workout.title),
                  subtitle: Text('${DateFormat.MMMEd().format(workout.scheduledDate)} · ${workout.estimatedMinutes ?? '—'} min'),
                  trailing: Text(workout.status),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
