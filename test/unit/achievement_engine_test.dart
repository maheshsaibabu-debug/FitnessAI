import 'package:fitness_companion/domain/progress_engine/achievement_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const AchievementEngine();

  test('first workout unlocks "first_workout" only, not thresholds not yet reached', () {
    final unlocked = engine.newlyUnlocked(
      stats: const AchievementStats(totalWorkoutsCompleted: 1),
      alreadyUnlockedKeys: {},
    );
    expect(unlocked.map((a) => a.key), ['first_workout']);
  });

  test('crossing multiple thresholds at once returns all of them', () {
    final unlocked = engine.newlyUnlocked(
      stats: const AchievementStats(totalWorkoutsCompleted: 10, workoutStreak: 7),
      alreadyUnlockedKeys: {},
    );
    expect(unlocked.map((a) => a.key).toSet(), {'first_workout', 'ten_workouts', 'streak_7'});
  });

  test('already-unlocked achievements are never returned again', () {
    final unlocked = engine.newlyUnlocked(
      stats: const AchievementStats(totalWorkoutsCompleted: 10),
      alreadyUnlockedKeys: {'first_workout', 'ten_workouts'},
    );
    expect(unlocked, isEmpty);
  });

  test('nothing unlocked when no thresholds are met', () {
    final unlocked = engine.newlyUnlocked(stats: const AchievementStats(), alreadyUnlockedKeys: {});
    expect(unlocked, isEmpty);
  });
}
