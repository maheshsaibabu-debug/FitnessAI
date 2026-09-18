import 'package:fitness_companion/domain/progress_engine/progress_analysis_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const ProgressAnalysisEngine();

  test('fewer than 2 samples -> no trend', () {
    expect(engine.weightTrend([]), isNull);
    expect(engine.weightTrend([WeightSample(DateTime(2026, 1, 1), 80)]), isNull);
  });

  test('steady loss over 4 weeks is reported as decreasing at roughly the true rate', () {
    final start = DateTime(2026, 1, 1);
    // Losing ~0.5kg/week for 28 days, with small daily noise.
    final samples = List.generate(29, (i) {
      final noise = (i % 3 == 0) ? 0.3 : (i % 3 == 1 ? -0.2 : 0.0);
      return WeightSample(start.add(Duration(days: i)), 80 - (0.5 / 7) * i + noise);
    });

    final trend = engine.weightTrend(samples)!;
    expect(trend.direction, TrendDirection.decreasing);
    expect(trend.ratePerWeek, closeTo(-0.5, 0.15));
  });

  test('a single noisy up-day among flat data does not flip the trend to increasing', () {
    final start = DateTime(2026, 1, 1);
    final samples = [
      WeightSample(start, 80.0),
      WeightSample(start.add(const Duration(days: 1)), 79.9),
      WeightSample(start.add(const Duration(days: 2)), 80.6), // noisy spike
      WeightSample(start.add(const Duration(days: 3)), 79.8),
      WeightSample(start.add(const Duration(days: 4)), 79.9),
    ];
    final trend = engine.weightTrend(samples)!;
    expect(trend.direction, isNot(TrendDirection.increasing));
  });

  test('adherenceRate clamps to [0,1] and treats zero scheduled as full adherence', () {
    expect(engine.adherenceRate(scheduled: 0, completed: 0), 1.0);
    expect(engine.adherenceRate(scheduled: 4, completed: 2), 0.5);
    expect(engine.adherenceRate(scheduled: 4, completed: 6), 1.0);
  });
}
