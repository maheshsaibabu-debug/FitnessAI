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
}
