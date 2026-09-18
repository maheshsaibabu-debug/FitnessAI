enum TrendDirection { increasing, decreasing, stable }

class WeightTrend {
  const WeightTrend({
    required this.direction,
    required this.ratePerWeek,
    required this.movingAverage,
    required this.startingWeight,
    required this.currentWeight,
  });

  final TrendDirection direction;

  /// kg/week, positive = gaining, negative = losing. Derived from a linear
  /// regression over the window, not a point-to-point diff, precisely so
  /// a single noisy day (water weight, meal timing) doesn't flip the
  /// interpretation — the product spec (§23) explicitly calls for
  /// trend-based reading, not reacting to daily fluctuations.
  final double ratePerWeek;
  final double movingAverage;
  final double startingWeight;
  final double currentWeight;
}

class WeightSample {
  const WeightSample(this.date, this.weightKg);
  final DateTime date;
  final double weightKg;
}

/// Reads trends out of noisy day-to-day logs — the antidote to "the scale
/// said +0.4kg today, panic." No LLM; this is plain regression math.
class ProgressAnalysisEngine {
  const ProgressAnalysisEngine();

  /// [stableThresholdKgPerWeek] is the rate below which a trend is
  /// reported as "stable" rather than a direction — small week-to-week
  /// noise shouldn't read as a spurious increase or decrease.
  WeightTrend? weightTrend(List<WeightSample> samples, {double stableThresholdKgPerWeek = 0.1}) {
    if (samples.length < 2) return null;

    final sorted = [...samples]..sort((a, b) => a.date.compareTo(b.date));
    final firstDay = sorted.first.date;

    // x = days since the first sample, y = weight. Ordinary least squares.
    final xs = sorted.map((s) => s.date.difference(firstDay).inHours / 24.0).toList();
    final ys = sorted.map((s) => s.weightKg).toList();

    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;

    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      numerator += (xs[i] - meanX) * (ys[i] - meanY);
      denominator += (xs[i] - meanX) * (xs[i] - meanX);
    }
    final slopePerDay = denominator == 0 ? 0.0 : numerator / denominator;
    final ratePerWeek = slopePerDay * 7;

    final direction = ratePerWeek.abs() < stableThresholdKgPerWeek
        ? TrendDirection.stable
        : (ratePerWeek > 0 ? TrendDirection.increasing : TrendDirection.decreasing);

    return WeightTrend(
      direction: direction,
      ratePerWeek: double.parse(ratePerWeek.toStringAsFixed(2)),
      movingAverage: double.parse(meanY.toStringAsFixed(1)),
      startingWeight: sorted.first.weightKg,
      currentWeight: sorted.last.weightKg,
    );
  }

  /// Fraction of scheduled workouts actually completed over a window —
  /// the number the adaptive-plan engine and the coach both key off of.
  double adherenceRate({required int scheduled, required int completed}) {
    if (scheduled <= 0) return 1.0;
    return (completed / scheduled).clamp(0.0, 1.0);
  }
}
