import 'package:fitness_companion/domain/program_engine/program_trajectory_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ProgramTrajectoryEngine();
  final today = DateTime(2026, 1, 1);

  test('a reasonable loss pace (the product-spec example: 85 -> 70kg over 6 months) is not adjusted', () {
    final trajectory = engine.compute(ProgramTrajectoryInput(
      currentWeightKg: 85,
      goalWeightKg: 70,
      requestedTargetDate: DateTime(2026, 7, 1), // ~26 weeks, ~0.58kg/week, under the 1%/week (0.85kg) cap
      today: today,
    ));

    expect(trajectory.wasAdjusted, isFalse);
    expect(trajectory.adjustmentReason, isNull);
    expect(trajectory.effectiveTargetDate, DateTime(2026, 7, 1));
    expect(trajectory.weeklyRateKg, lessThan(0)); // losing
  });

  test('an unsafe loss pace gets its timeline extended, never its rate left as-is', () {
    final trajectory = engine.compute(ProgramTrajectoryInput(
      currentWeightKg: 85,
      goalWeightKg: 70, // 15kg
      requestedTargetDate: DateTime(2026, 2, 1), // ~4.4 weeks -> ~3.4kg/week, wildly over the ~0.85kg/week cap
      today: today,
    ));

    expect(trajectory.wasAdjusted, isTrue);
    expect(trajectory.adjustmentReason, isNotNull);
    expect(trajectory.effectiveTargetDate.isAfter(DateTime(2026, 2, 1)), isTrue);
    // The capped rate should never exceed 1% of starting bodyweight per week.
    expect(trajectory.weeklyRateKg.abs(), lessThanOrEqualTo(85 * ProgramTrajectoryEngine.maxLossRateFraction + 0.001));
  });

  test('an unsafe gain pace uses the tighter lean-gain cap, not the loss cap', () {
    final trajectory = engine.compute(ProgramTrajectoryInput(
      currentWeightKg: 70,
      goalWeightKg: 80, // 10kg gain
      requestedTargetDate: DateTime(2026, 2, 1), // way too fast for lean gain
      today: today,
    ));

    expect(trajectory.wasAdjusted, isTrue);
    expect(trajectory.weeklyRateKg, greaterThan(0)); // gaining
    expect(trajectory.weeklyRateKg, lessThanOrEqualTo(70 * ProgramTrajectoryEngine.maxGainRateFraction + 0.001));
  });

  test('milestones start at the real current weight and end at the goal weight', () {
    final trajectory = engine.compute(ProgramTrajectoryInput(
      currentWeightKg: 85,
      goalWeightKg: 70,
      requestedTargetDate: DateTime(2026, 7, 1),
      today: today,
    ));

    expect(trajectory.milestones.first.weightKg, 85);
    expect(trajectory.milestones.first.label, 'Start');
    expect(trajectory.milestones.last.weightKg, 70);
    expect(trajectory.milestones.last.label, 'Goal');
    // Monotonically decreasing toward the goal, never overshooting or reversing.
    for (var i = 1; i < trajectory.milestones.length; i++) {
      expect(trajectory.milestones[i].weightKg, lessThanOrEqualTo(trajectory.milestones[i - 1].weightKg));
    }
  });

  test('goal already met (same weight) produces a flat, non-adjusted trajectory', () {
    final trajectory = engine.compute(ProgramTrajectoryInput(
      currentWeightKg: 70,
      goalWeightKg: 70,
      requestedTargetDate: DateTime(2026, 7, 1),
      today: today,
    ));

    expect(trajectory.wasAdjusted, isFalse);
    expect(trajectory.weeklyRateKg, 0);
    expect(trajectory.milestones, hasLength(1));
  });

  test('a target date in the past does not produce a negative-length plan', () {
    final trajectory = engine.compute(ProgramTrajectoryInput(
      currentWeightKg: 85,
      goalWeightKg: 70,
      requestedTargetDate: DateTime(2025, 6, 1), // before `today`
      today: today,
    ));

    expect(trajectory.milestones, hasLength(1));
    expect(trajectory.weeklyRateKg, 0);
  });
}
