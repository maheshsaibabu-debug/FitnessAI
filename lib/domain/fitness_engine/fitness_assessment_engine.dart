enum FitnessLevel { beginner, intermediate, advanced }

enum AssessmentSex { male, female, other }

class BaselineInput {
  const BaselineInput({
    this.pushUpsReps,
    this.squatsReps,
    this.pullUpsReps,
    this.plankSeconds,
  });

  final int? pushUpsReps;
  final int? squatsReps;
  final int? pullUpsReps;
  final int? plankSeconds;
}

class FitnessAssessmentResult {
  const FitnessAssessmentResult({required this.overallLevel, required this.perMetricLevels});

  final FitnessLevel overallLevel;

  /// e.g. {'push_ups': intermediate, 'plank': beginner, ...} — surfaced so
  /// the workout generator can pick a level per movement pattern rather
  /// than forcing one global difficulty on every exercise.
  final Map<String, FitnessLevel> perMetricLevels;
}

/// Classifies a lightweight self-test (product spec §17) into a starting
/// fitness level. The thresholds below are deliberately simple, rough
/// population norms — not a medical or sports-science instrument — good
/// enough to pick a sensible starting difficulty, which is all this needs
/// to do; the adaptive engine corrects for a wrong initial guess from
/// real performance afterwards.
class FitnessAssessmentEngine {
  const FitnessAssessmentEngine();

  FitnessAssessmentResult assess({required AssessmentSex sex, required BaselineInput baseline}) {
    final levels = <String, FitnessLevel>{};

    if (baseline.pushUpsReps != null) {
      levels['push_ups'] = _classify(baseline.pushUpsReps!, _pushUpThresholds(sex));
    }
    if (baseline.squatsReps != null) {
      levels['squats'] = _classify(baseline.squatsReps!, _squatThresholds(sex));
    }
    if (baseline.pullUpsReps != null) {
      levels['pull_ups'] = _classify(baseline.pullUpsReps!, _pullUpThresholds(sex));
    }
    if (baseline.plankSeconds != null) {
      levels['plank'] = _classify(baseline.plankSeconds!, const (beginner: 30, advanced: 90));
    }

    if (levels.isEmpty) {
      return const FitnessAssessmentResult(overallLevel: FitnessLevel.beginner, perMetricLevels: {});
    }

    // Overall level is the weakest-link classification (the lowest of the
    // per-metric levels), not an average — starting a new user's program
    // too hard is a worse failure mode than starting it slightly too easy.
    final overall = levels.values.reduce((a, b) => a.index < b.index ? a : b);

    return FitnessAssessmentResult(overallLevel: overall, perMetricLevels: levels);
  }

  FitnessLevel _classify(int value, ({int beginner, int advanced}) thresholds) {
    if (value < thresholds.beginner) return FitnessLevel.beginner;
    if (value < thresholds.advanced) return FitnessLevel.intermediate;
    return FitnessLevel.advanced;
  }

  ({int beginner, int advanced}) _pushUpThresholds(AssessmentSex sex) => switch (sex) {
        AssessmentSex.male => (beginner: 10, advanced: 25),
        AssessmentSex.female => (beginner: 5, advanced: 15),
        AssessmentSex.other => (beginner: 8, advanced: 20),
      };

  ({int beginner, int advanced}) _squatThresholds(AssessmentSex sex) => switch (sex) {
        AssessmentSex.male => (beginner: 15, advanced: 30),
        AssessmentSex.female => (beginner: 12, advanced: 25),
        AssessmentSex.other => (beginner: 13, advanced: 27),
      };

  ({int beginner, int advanced}) _pullUpThresholds(AssessmentSex sex) => switch (sex) {
        AssessmentSex.male => (beginner: 1, advanced: 9),
        AssessmentSex.female => (beginner: 1, advanced: 4),
        AssessmentSex.other => (beginner: 1, advanced: 6),
      };
}
