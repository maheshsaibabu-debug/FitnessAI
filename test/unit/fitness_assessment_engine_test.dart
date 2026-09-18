import 'package:fitness_companion/domain/fitness_engine/fitness_assessment_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const FitnessAssessmentEngine();

  test('no baseline data -> defaults to beginner', () {
    final result = engine.assess(sex: AssessmentSex.male, baseline: const BaselineInput());
    expect(result.overallLevel, FitnessLevel.beginner);
    expect(result.perMetricLevels, isEmpty);
  });

  test('strong numbers across the board -> advanced overall', () {
    final result = engine.assess(
      sex: AssessmentSex.male,
      baseline: const BaselineInput(pushUpsReps: 30, squatsReps: 35, pullUpsReps: 12, plankSeconds: 120),
    );
    expect(result.overallLevel, FitnessLevel.advanced);
    expect(result.perMetricLevels['push_ups'], FitnessLevel.advanced);
  });

  test('overall level is the weakest link, not an average', () {
    // Strong push-ups (advanced) but zero pull-ups (beginner) -> overall
    // must not be dragged up to advanced/intermediate by the strong metric.
    final result = engine.assess(
      sex: AssessmentSex.male,
      baseline: const BaselineInput(pushUpsReps: 30, pullUpsReps: 0),
    );
    expect(result.perMetricLevels['push_ups'], FitnessLevel.advanced);
    expect(result.perMetricLevels['pull_ups'], FitnessLevel.beginner);
    expect(result.overallLevel, FitnessLevel.beginner);
  });

  test('female thresholds differ from male thresholds for the same raw number', () {
    // 16 push-ups: below the male "advanced" bar (25) but above the
    // female one (15) — the classification should genuinely differ.
    final maleResult = engine.assess(sex: AssessmentSex.male, baseline: const BaselineInput(pushUpsReps: 16));
    final femaleResult = engine.assess(sex: AssessmentSex.female, baseline: const BaselineInput(pushUpsReps: 16));
    expect(maleResult.perMetricLevels['push_ups'], FitnessLevel.intermediate);
    expect(femaleResult.perMetricLevels['push_ups'], FitnessLevel.advanced);
  });
}
