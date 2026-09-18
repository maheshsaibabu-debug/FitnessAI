import 'package:fitness_companion/domain/streak_engine/streak_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const StreakEngine();
  final today = DateTime(2026, 9, 18);

  test('empty history -> zero streak', () {
    final result = engine.calculate([], asOf: today);
    expect(result.currentStreak, 0);
    expect(result.longestStreak, 0);
  });

  test('5 consecutive days ending today -> current streak of 5', () {
    final dates = List.generate(5, (i) => today.subtract(Duration(days: i)));
    final result = engine.calculate(dates, asOf: today);
    expect(result.currentStreak, 5);
    expect(result.longestStreak, 5);
    expect(result.isActiveToday, isTrue);
  });

  test('streak continues counting from yesterday if today has not happened yet', () {
    final dates = [
      today.subtract(const Duration(days: 1)),
      today.subtract(const Duration(days: 2)),
      today.subtract(const Duration(days: 3)),
    ];
    final result = engine.calculate(dates, asOf: today);
    expect(result.currentStreak, 3);
    expect(result.isActiveToday, isFalse);
  });

  test('a gap breaks the current streak but longest streak still reflects history', () {
    final dates = [
      today, // active today
      today.subtract(const Duration(days: 3)),
      today.subtract(const Duration(days: 4)),
      today.subtract(const Duration(days: 5)),
      today.subtract(const Duration(days: 6)),
    ];
    final result = engine.calculate(dates, asOf: today);
    expect(result.currentStreak, 1); // today only, day -1 and -2 are missing
    expect(result.longestStreak, 4); // the -3..-6 run
  });

  test('duplicate same-day entries do not inflate the streak', () {
    final dates = [today, today, today.subtract(const Duration(days: 1))];
    final result = engine.calculate(dates, asOf: today);
    expect(result.currentStreak, 2);
  });
}
