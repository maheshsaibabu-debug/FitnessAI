class StreakResult {
  const StreakResult({required this.currentStreak, required this.longestStreak, required this.isActiveToday});

  /// Consecutive days up to and including today (or yesterday, if today
  /// hasn't happened yet but yesterday's chain is unbroken — a streak
  /// doesn't reset to zero the moment the clock rolls over).
  final int currentStreak;
  final int longestStreak;
  final bool isActiveToday;
}

/// Computes streaks from a set of "this happened on this day" dates —
/// used for workout, step-goal, check-in, and nutrition-logging streaks
/// alike (the product spec §31 calls for all four). Pure date-set math,
/// no network, no LLM.
class StreakEngine {
  const StreakEngine();

  StreakResult calculate(List<DateTime> completedDates, {DateTime? asOf}) {
    final today = _dateOnly(asOf ?? DateTime.now());

    if (completedDates.isEmpty) {
      return const StreakResult(currentStreak: 0, longestStreak: 0, isActiveToday: false);
    }

    final days = completedDates.map(_dateOnly).toSet().toList()..sort();

    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    final daySet = days.toSet();
    final isActiveToday = daySet.contains(today);
    var cursor = isActiveToday ? today : today.subtract(const Duration(days: 1));

    var current = 0;
    while (daySet.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return StreakResult(currentStreak: current, longestStreak: longest, isActiveToday: isActiveToday);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
