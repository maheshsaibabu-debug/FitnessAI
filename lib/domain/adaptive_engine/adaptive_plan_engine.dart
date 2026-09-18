/// What was planned vs. what actually happened last week, per workout
/// category. `consecutiveLowAdherenceWeeks` lets the caller tell the
/// engine "this isn't the first time" so repeated misses compound into a
/// bigger reduction rather than resetting the same small nudge every week.
class WeeklyAdherence {
  const WeeklyAdherence({
    required this.plannedStrengthSessions,
    required this.actualStrengthSessions,
    required this.plannedHiitSessions,
    required this.actualHiitSessions,
    this.consecutiveLowAdherenceWeeks = 0,
  });

  final int plannedStrengthSessions;
  final int actualStrengthSessions;
  final int plannedHiitSessions;
  final int actualHiitSessions;
  final int consecutiveLowAdherenceWeeks;
}

class AdaptivePlanAdjustment {
  const AdaptivePlanAdjustment({
    required this.nextStrengthSessions,
    required this.nextHiitSessions,
    required this.shortenHiitSessions,
    required this.rationale,
  });

  final int nextStrengthSessions;
  final int nextHiitSessions;

  /// True when HIIT was dropped for being unsustainable rather than
  /// unwanted — offering a shorter session next time instead of just
  /// fewer of them (matches the product spec's exact "3 strength / 1
  /// shorter HIIT" example).
  final bool shortenHiitSessions;
  final String rationale;
}

/// Turns last week's actual adherence into next week's planned session
/// counts. The objective (product spec §34) is sustainable consistency,
/// not punishing a miss — a plan that's repeatedly failed is a plan that
/// was wrong for this person, and the fix is to right-size it, not repeat
/// it unchanged and hope for a different result.
class AdaptivePlanEngine {
  const AdaptivePlanEngine();

  static const int _minStrengthSessions = 2;

  AdaptivePlanAdjustment adjust(WeeklyAdherence last) {
    final strengthRatio = last.plannedStrengthSessions == 0
        ? 1.0
        : last.actualStrengthSessions / last.plannedStrengthSessions;
    final hiitRatio =
        last.plannedHiitSessions == 0 ? 1.0 : last.actualHiitSessions / last.plannedHiitSessions;

    var nextStrength = last.plannedStrengthSessions;
    var strengthNote = 'Strength adherence was solid — keeping the same target.';
    if (strengthRatio < 0.5) {
      final reduction = last.consecutiveLowAdherenceWeeks >= 2 ? 2 : 1;
      nextStrength = (last.plannedStrengthSessions - reduction).clamp(_minStrengthSessions, 7);
      strengthNote =
          'Only ${(strengthRatio * 100).round()}% of planned strength sessions happened — reducing the target so it is actually achievable.';
    } else if (strengthRatio < 0.8) {
      strengthNote = 'Strength adherence was close but not complete — holding the target for another week.';
    }

    var nextHiit = last.plannedHiitSessions;
    var shortenHiit = false;
    var hiitNote = 'HIIT adherence was solid — keeping the same target.';
    if (hiitRatio == 0 && last.plannedHiitSessions > 0) {
      nextHiit = (last.plannedHiitSessions - 1).clamp(0, 7);
      shortenHiit = nextHiit > 0;
      hiitNote = 'HIIT was skipped entirely last week — planning fewer, shorter sessions instead of the same load.';
    } else if (hiitRatio < 0.5) {
      nextHiit = (last.plannedHiitSessions - 1).clamp(0, 7);
      hiitNote = 'Less than half of planned HIIT sessions happened — trimming next week\'s target.';
    }

    return AdaptivePlanAdjustment(
      nextStrengthSessions: nextStrength,
      nextHiitSessions: nextHiit,
      shortenHiitSessions: shortenHiit,
      rationale: '$strengthNote $hiitNote',
    );
  }
}
