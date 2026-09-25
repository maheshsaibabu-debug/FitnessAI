enum MotivationMoment { morningPlanReady, midWeekProgress, weeklyCelebration, comebackAfterBreak, streakAtRisk }

class MotivationContext {
  const MotivationContext({
    required this.moment,
    this.workoutsRemainingThisWeek,
    this.workoutsCompletedThisWeek,
    this.currentStreak,
    this.daysSinceLastActivity,
  });

  final MotivationMoment moment;
  final int? workoutsRemainingThisWeek;
  final int? workoutsCompletedThisWeek;
  final int? currentStreak;
  final int? daysSinceLastActivity;
}

/// Deterministic, rule-based copy — no LLM. This is what the AI coach
/// (phase 11) falls back to when the cloud is unreachable, and what the
/// notification scheduler uses directly for anything that must work
/// offline (product spec §29, §15). Every template here is checked against
/// the spec's explicit rule: no guilt, no shame, no insults.
class MotivationEngine {
  const MotivationEngine();

  String messageFor(MotivationContext context) {
    switch (context.moment) {
      case MotivationMoment.morningPlanReady:
        return 'Your plan is ready.';

      case MotivationMoment.midWeekProgress:
        final remaining = context.workoutsRemainingThisWeek ?? 0;
        if (remaining <= 0) {
          return 'You\'ve hit your weekly workout target already — nice work.';
        }
        if (remaining == 1) {
          return 'You\'re one workout away from your weekly target.';
        }
        return 'You have $remaining workouts left to hit your weekly target.';

      case MotivationMoment.weeklyCelebration:
        final completed = context.workoutsCompletedThisWeek ?? 0;
        return '\u{1F525} $completed workout${completed == 1 ? '' : 's'} completed this week.';

      case MotivationMoment.comebackAfterBreak:
        return 'Let\'s restart with a simple 10-minute session.';

      case MotivationMoment.streakAtRisk:
        final streak = context.currentStreak ?? 0;
        if (streak <= 0) {
          return 'Ready when you are — every streak starts with one day.';
        }
        return 'Your $streak-day streak is still alive today — one more to keep it going.';
    }
  }

  /// Shown when a streak breaks. Explicitly never framed as a failure —
  /// product spec §31: "Your streak ended. Your progress didn't."
  String streakEndedMessage() => 'Your streak ended. Your progress didn\'t.';

  static const List<String> _dailyQuotes = [
    'Small steps create big results.',
    'The only bad workout is the one that didn\'t happen.',
    'Discipline is choosing between what you want now and what you want most.',
    'You don\'t have to be extreme, just consistent.',
    'Progress, not perfection.',
    'Your body can stand almost anything. It\'s your mind you have to convince.',
    'Every workout is progress, no matter how small.',
    'Motivation gets you started. Habit keeps you going.',
    'Push yourself, because no one else is going to do it for you.',
    'The pain of discipline weighs ounces; the pain of regret weighs tons.',
    'Sweat is just fat crying.',
    'A one-hour workout is 4% of your day. No excuses.',
    'Strength doesn\'t come from what you can do. It comes from overcoming what you thought you couldn\'t.',
    'Success starts with self-discipline.',
    'The only way to finish is to start.',
    'Don\'t stop when you\'re tired. Stop when you\'re done.',
    'What seems impossible today will one day become your warm-up.',
    'Your future self is watching you right now through memories.',
    'The hardest lift is lifting yourself off the couch.',
    'Consistency is what transforms average into excellence.',
    'You are one workout away from a good mood.',
    'Take care of your body. It\'s the only place you have to live.',
    'Nothing changes if nothing changes.',
    'It never gets easier, you just get stronger.',
    'Rest, but never quit.',
    'The body achieves what the mind believes.',
    'Fall in love with the process, and the results will follow.',
    'Today\'s effort is tomorrow\'s strength.',
  ];

  /// A stable "quote of the day" — the same quote all day for [date], a
  /// different one the next, cycling through the list rather than picking
  /// randomly so it's deterministic (no seed/state to persist) and never
  /// repeats two days in a row within one cycle.
  String dailyQuote(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year)).inDays;
    return _dailyQuotes[dayOfYear % _dailyQuotes.length];
  }
}
