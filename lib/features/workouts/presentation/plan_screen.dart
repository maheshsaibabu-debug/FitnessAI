import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../ai/ai_providers.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../domain/workout_engine/workout_generation_engine.dart';
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

/// Lists the generated plan's upcoming workouts. The adaptive re-planning
/// from actual adherence (phase 10) is still a later phase, but a manual
/// "Regenerate" is available now — it tries the AI plan generator first
/// (ai/plan/plan_generation_service.dart) and falls back to
/// [WorkoutGenerationEngine] if that's unavailable, against the same
/// saved profile. The SnackBar after a regenerate says which one ran.
class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  bool _regenerating = false;

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      final profileRepository = ref.read(profileRepositoryProvider);
      final profile = await profileRepository.activeProfileOnce();
      final trainingProfile = await profileRepository.currentTrainingProfile();
      if (profile == null || trainingProfile == null) return;

      final latestWeight = await ref.read(weightRepositoryProvider).latestOnce(profile.id);
      final primaryGoal = await profileRepository.primaryGoalOnce(profile.id);
      final nutritionInput = nutritionRequestInputForProfile(
        profile,
        weightKg: latestWeight?.weightKg ?? 70,
        primaryGoal: primaryGoal,
      );

      final exerciseLibrarySeeder = ref.read(exerciseLibrarySeederProvider);
      await exerciseLibrarySeeder.seedIfEmpty();
      final library = await exerciseLibrarySeeder.loadSummaries();

      final result = await ref.read(planGenerationServiceProvider).generate(
            trainingProfile: trainingProfile,
            library: library,
            nutritionInput: nutritionInput,
          );

      await ref.read(workoutPlanRepositoryProvider).persistUpcomingPlanReplacement(
            userId: profile.id,
            generated: result.plan,
            from: DateTime.now(),
          );
      await profileRepository.updateNutritionTargets(profile.id, result.nutrition);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.source == 'ai'
                  ? 'Plan regenerated with AI from today onward.'
                  : 'Plan regenerated from today onward (offline mode).',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = ref.watch(upcomingWorkoutsProvider);
    final goals = ref.watch(activeGoalsProvider).valueOrNull ?? const {};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          IconButton(
            tooltip: 'Regenerate plan',
            icon: _regenerating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _regenerating ? null : _regenerate,
          ),
        ],
      ),
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
                              const SizedBox(height: 2),
                              Text(
                                workoutFocusSummary(workoutType: workout.workoutType, goals: goals),
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
