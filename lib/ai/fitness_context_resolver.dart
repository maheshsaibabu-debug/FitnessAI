import '../data/repositories/profile_repository.dart';
import '../data/repositories/steps_repository.dart';
import '../data/repositories/weight_repository.dart';
import '../data/repositories/workout_plan_repository.dart';
import '../domain/streak_engine/streak_engine.dart';
import 'fitness_context.dart';

/// Assembles the bounded [FitnessContext] sent to the AI gateway —
/// docs/AI_ARCHITECTURE.md's FitnessContextResolver. Reads only what's
/// already computed/stored locally; never talks to the network itself.
class FitnessContextResolver {
  FitnessContextResolver({
    required this.profileRepository,
    required this.workoutPlanRepository,
    required this.stepsRepository,
    required this.weightRepository,
  });

  final ProfileRepository profileRepository;
  final WorkoutPlanRepository workoutPlanRepository;
  final StepsRepository stepsRepository;
  final WeightRepository weightRepository;

  /// Returns null when there's no local profile yet (onboarding
  /// incomplete) — the coach feature should never call the gateway in
  /// that case, there's nothing real to summarize.
  Future<FitnessContext?> resolve() async {
    final profile = await profileRepository.activeProfileOnce();
    if (profile == null) return null;

    final goals = await profileRepository.goalsOnce(profile.id);
    final recentWorkouts = await workoutPlanRepository.recentWorkouts(profile.id, days: 14);
    final nextWorkout = await workoutPlanRepository.nextUpcomingWorkout(profile.id);
    final stepHistory = await stepsRepository.historyOnce(profile.id, days: 7);
    final weightHistory = await weightRepository.historyOnce(profile.id, days: 60);
    final nutritionTargets = await profileRepository.nutritionTargetsOnce(profile.id);

    final completed = recentWorkouts.where((w) => w.status == 'completed').toList();
    final skipped = recentWorkouts.where((w) => w.status == 'skipped' || w.status == 'couldnt_complete').toList();
    final happened = recentWorkouts.where((w) => w.status != 'scheduled');
    final lastHappened = happened.isEmpty ? null : happened.first;
    final streak = const StreakEngine().calculate(completed.map((w) => w.scheduledDate).toList());

    return FitnessContext(
      name: profile.name,
      goals: goals,
      fitnessLevel: profile.fitnessLevel ?? 'beginner',
      currentStreak: streak.currentStreak,
      workoutsCompletedLast14Days: completed.length,
      workoutsSkippedLast14Days: skipped.length,
      workoutsScheduledLast14Days: recentWorkouts.length,
      nextWorkoutTitle: nextWorkout?.title,
      nextWorkoutDate: nextWorkout?.scheduledDate,
      lastWorkoutTitle: lastHappened?.title,
      lastWorkoutStatus: lastHappened?.status,
      stepAverageLast7Days: stepHistory.isEmpty
          ? null
          : stepHistory.map((r) => r.steps).reduce((a, b) => a + b) / stepHistory.length,
      latestWeightKg: weightHistory.isEmpty ? null : weightHistory.last.weightKg,
      weightTrendKgPerWeek: _weeklyTrend(weightHistory.map((w) => (w.recordedAt, w.weightKg)).toList()),
      calorieTarget: nutritionTargets?.calorieTarget,
      proteinGrams: nutritionTargets?.proteinGrams,
    );
  }

  /// kg/week between the first and last entry in the window — a simple
  /// two-point slope, not a regression; good enough for "roughly gaining
  /// / losing / stable" framing, which is all the coach needs.
  double? _weeklyTrend(List<(DateTime, double)> entries) {
    if (entries.length < 2) return null;
    final first = entries.first;
    final last = entries.last;
    final days = last.$1.difference(first.$1).inDays;
    if (days <= 0) return null;
    return (last.$2 - first.$2) / (days / 7);
  }
}
