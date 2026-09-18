/// Which way the next session's target should move.
enum ProgressionDirection { increase, hold, decrease }

class ProgressionRecommendation {
  const ProgressionRecommendation({
    required this.nextTarget,
    required this.direction,
    required this.rationale,
  });

  /// The recommended target for the next session, in the same unit as the
  /// input (reps, or kg for weight-based exercises).
  final num nextTarget;
  final ProgressionDirection direction;

  /// Human-readable reason, surfaced to the user (and to the AI coach as
  /// context) so a plan change is never unexplained.
  final String rationale;
}

/// Turns "what actually happened in the last session" into "what should
/// the next session target be." Pure arithmetic — no LLM, no network,
/// no database — so it's trivially unit-testable and always available
/// offline. See docs/FITNESS_ENGINE.md.
///
/// The rule, in plain terms: if every set met the target and it didn't
/// feel maximal (RPE <= 7), there's room to progress — increase by one
/// increment. If sets were missed AND the session felt like a true limit
/// (RPE >= 9) by a meaningful margin, the target was too ambitious —
/// reset to what was actually sustainable rather than repeating a target
/// that's likely to fail again. Everything in between holds the current
/// target for another attempt, since a single off day (fatigue, sleep,
/// stress) isn't evidence the target itself is wrong.
class WorkoutProgressionEngine {
  const WorkoutProgressionEngine();

  static const int _defaultRepIncrement = 1;
  static const double _defaultWeightIncrementKg = 2.5;

  /// Reps-based exercises (push-ups, pull-ups, squats, etc.).
  ///
  /// Example from the product spec: target 3x6 pull-ups, actual [6,6,6],
  /// RPE 6 -> recommends 7 (all sets met, plenty of headroom).
  /// Target 3x8, actual [8,6,5], RPE 9 -> recommends 6 (missed badly at
  /// a near-maximal effort, so reset to the average actually achieved).
  ProgressionRecommendation recommendNextReps({
    required int targetReps,
    required List<int> actualReps,
    required int rpe,
    int increment = _defaultRepIncrement,
  }) {
    final rec = _recommend(
      targetValue: targetReps.toDouble(),
      actualValues: actualReps.map((r) => r.toDouble()).toList(),
      rpe: rpe,
      increment: increment.toDouble(),
    );
    return ProgressionRecommendation(
      nextTarget: rec.nextTarget.round(),
      direction: rec.direction,
      rationale: rec.rationale,
    );
  }

  /// Weight-based exercises (bench, squat, deadlift, etc.). Same logic,
  /// operating on load instead of reps, deloading/progressing in plate-
  /// realistic increments (default 2.5kg).
  ProgressionRecommendation recommendNextWeightKg({
    required double targetWeightKg,
    required List<double> actualWeightsKg,
    required int rpe,
    double incrementKg = _defaultWeightIncrementKg,
  }) {
    return _recommend(
      targetValue: targetWeightKg,
      actualValues: actualWeightsKg,
      rpe: rpe,
      increment: incrementKg,
    );
  }

  ProgressionRecommendation _recommend({
    required double targetValue,
    required List<double> actualValues,
    required int rpe,
    required double increment,
  }) {
    assert(actualValues.isNotEmpty, 'Cannot recommend a progression with no logged sets');

    final allSetsMetTarget = actualValues.every((v) => v >= targetValue);
    final average = actualValues.reduce((a, b) => a + b) / actualValues.length;

    if (allSetsMetTarget) {
      if (rpe <= 7) {
        return ProgressionRecommendation(
          nextTarget: _roundToIncrement(targetValue + increment, increment),
          direction: ProgressionDirection.increase,
          rationale: 'Every set met target at RPE $rpe — there was room to spare, so pushing the target up.',
        );
      }
      return ProgressionRecommendation(
        nextTarget: _roundToIncrement(targetValue, increment),
        direction: ProgressionDirection.hold,
        rationale: 'Every set met target, but RPE $rpe was near maximal — holding here to consolidate before increasing.',
      );
    }

    final deficit = targetValue - average;
    if (rpe >= 9 && deficit > 1) {
      return ProgressionRecommendation(
        nextTarget: _roundToIncrement(average, increment),
        direction: ProgressionDirection.decrease,
        rationale:
            'Missed target by ${deficit.toStringAsFixed(1)} at RPE $rpe (near failure) — resetting to what was actually sustainable.',
      );
    }

    return ProgressionRecommendation(
      nextTarget: _roundToIncrement(targetValue, increment),
      direction: ProgressionDirection.hold,
      rationale: 'Target was missed, but not at a true limit — holding the same target for another attempt.',
    );
  }

  double _roundToIncrement(double value, double increment) {
    if (increment <= 0) return value;
    return (value / increment).round() * increment;
  }
}
