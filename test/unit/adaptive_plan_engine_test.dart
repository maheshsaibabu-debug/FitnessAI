import 'package:fitness_companion/domain/adaptive_engine/adaptive_plan_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const AdaptivePlanEngine();

  test('product-spec example: strength kept, HIIT reduced and shortened after being fully skipped', () {
    final adjustment = engine.adjust(const WeeklyAdherence(
      plannedStrengthSessions: 3,
      actualStrengthSessions: 3,
      plannedHiitSessions: 2,
      actualHiitSessions: 0,
    ));

    expect(adjustment.nextStrengthSessions, 3);
    expect(adjustment.nextHiitSessions, 1);
    expect(adjustment.shortenHiitSessions, isTrue);
  });

  test('repeatedly missed strength sessions reduce workload further, not just once', () {
    final firstMiss = engine.adjust(const WeeklyAdherence(
      plannedStrengthSessions: 4,
      actualStrengthSessions: 1,
      plannedHiitSessions: 0,
      actualHiitSessions: 0,
    ));
    expect(firstMiss.nextStrengthSessions, 3);

    final repeatedMiss = engine.adjust(const WeeklyAdherence(
      plannedStrengthSessions: 4,
      actualStrengthSessions: 1,
      plannedHiitSessions: 0,
      actualHiitSessions: 0,
      consecutiveLowAdherenceWeeks: 2,
    ));
    expect(repeatedMiss.nextStrengthSessions, 2);
  });

  test('never reduces strength below the minimum sustainable floor', () {
    final adjustment = engine.adjust(const WeeklyAdherence(
      plannedStrengthSessions: 2,
      actualStrengthSessions: 0,
      plannedHiitSessions: 0,
      actualHiitSessions: 0,
      consecutiveLowAdherenceWeeks: 5,
    ));
    expect(adjustment.nextStrengthSessions, greaterThanOrEqualTo(2));
  });

  test('perfect adherence holds targets steady rather than escalating', () {
    final adjustment = engine.adjust(const WeeklyAdherence(
      plannedStrengthSessions: 3,
      actualStrengthSessions: 3,
      plannedHiitSessions: 2,
      actualHiitSessions: 2,
    ));
    expect(adjustment.nextStrengthSessions, 3);
    expect(adjustment.nextHiitSessions, 2);
    expect(adjustment.shortenHiitSessions, isFalse);
  });
}
