/// Snapshot of the numbers achievement rules key off of. Deliberately a
/// flat bag of primitives (not a live DB query) so this engine stays pure
/// and testable — the repository layer is responsible for assembling one
/// from real data.
class AchievementStats {
  const AchievementStats({
    this.workoutStreak = 0,
    this.totalWorkoutsCompleted = 0,
    this.maxPullUps = 0,
    this.maxPushUps = 0,
    this.totalStepsThisWeek = 0,
  });

  final int workoutStreak;
  final int totalWorkoutsCompleted;
  final int maxPullUps;
  final int maxPushUps;
  final int totalStepsThisWeek;
}

typedef AchievementPredicate = bool Function(AchievementStats stats);

class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.isUnlocked,
  });

  final String key;
  final String title;
  final String description;
  final AchievementPredicate isUnlocked;
}

/// The fixed rule set. New achievements are added here as new predicates,
/// not invented by an LLM — this keeps "which achievements exist" a
/// closed, testable list (product spec §33/§37 — bundled/offline-safe).
final List<AchievementDefinition> achievementCatalog = [
  AchievementDefinition(
    key: 'first_workout',
    title: 'First Step',
    description: 'Complete your first workout.',
    isUnlocked: (s) => s.totalWorkoutsCompleted >= 1,
  ),
  AchievementDefinition(
    key: 'ten_workouts',
    title: 'Getting Started',
    description: 'Complete 10 workouts.',
    isUnlocked: (s) => s.totalWorkoutsCompleted >= 10,
  ),
  AchievementDefinition(
    key: 'fifty_workouts',
    title: 'Committed',
    description: 'Complete 50 workouts.',
    isUnlocked: (s) => s.totalWorkoutsCompleted >= 50,
  ),
  AchievementDefinition(
    key: 'streak_7',
    title: 'One Week Strong',
    description: 'Reach a 7-day streak.',
    isUnlocked: (s) => s.workoutStreak >= 7,
  ),
  AchievementDefinition(
    key: 'streak_30',
    title: 'Habit Formed',
    description: 'Reach a 30-day streak.',
    isUnlocked: (s) => s.workoutStreak >= 30,
  ),
  AchievementDefinition(
    key: 'first_pull_up',
    title: 'Up and Over',
    description: 'Complete your first strict pull-up.',
    isUnlocked: (s) => s.maxPullUps >= 1,
  ),
  AchievementDefinition(
    key: 'fifty_thousand_steps_week',
    title: 'On the Move',
    description: 'Log 50,000 steps in a single week.',
    isUnlocked: (s) => s.totalStepsThisWeek >= 50000,
  ),
];

/// Diffs "what's unlocked now" against "what was already unlocked" so the
/// caller knows exactly which achievements are newly earned this update —
/// the only ones that should trigger a celebration notification.
class AchievementEngine {
  const AchievementEngine();

  List<AchievementDefinition> newlyUnlocked({
    required AchievementStats stats,
    required Set<String> alreadyUnlockedKeys,
  }) {
    return achievementCatalog
        .where((a) => !alreadyUnlockedKeys.contains(a.key) && a.isUnlocked(stats))
        .toList();
  }
}
