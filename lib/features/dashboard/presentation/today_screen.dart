import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/offline_banner.dart';
import '../application/dashboard_providers.dart';

/// "Today" — answers "what should I do right now?" (product spec §21,
/// §39). Reads today's scheduled workout (if any) from the plan
/// generated at onboarding. Workout execution itself (starting it,
/// logging sets) is a later phase — this screen honestly shows what's
/// scheduled without pretending it can be started yet.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysWorkout = ref.watch(todaysWorkoutProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: todaysWorkout.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Could not load today\'s plan: $e')),
              data: (workout) => workout == null ? const _NoWorkoutToday() : _ScheduledWorkout(workout: workout),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoWorkoutToday extends StatelessWidget {
  const _NoWorkoutToday();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.self_improvement_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Rest day', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Nothing scheduled today. Check the Plan tab for what\'s coming up this week.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledWorkout extends StatelessWidget {
  const _ScheduledWorkout({required this.workout});
  final Workout workout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(workout.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('${workout.estimatedMinutes ?? '—'} min · ${workout.status}',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              Text(
                'Workout execution (starting it, logging sets) lands in implementation '
                'phase 7 — this card is real data from your generated plan, not a mock.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
