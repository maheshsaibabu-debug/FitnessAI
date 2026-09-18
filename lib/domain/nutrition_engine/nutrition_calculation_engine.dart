enum BiologicalSex { male, female, other }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum NutritionGoalType { fatLoss, muscleGain, weightGain, maintain, other }

class NutritionTargets {
  const NutritionTargets({
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.calculationMethod,
  });

  final int bmr;
  final int tdee;
  final int calorieTarget;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String calculationMethod;
}

/// Estimates a daily calorie/macro target. Every number here is a
/// population-formula estimate, not a medical measurement — the product
/// spec (§25) requires this be presented to the user as an estimate, and
/// requires avoiding extreme deficits/surpluses, which is why
/// [minSafeCalories] exists as a hard floor regardless of goal.
class NutritionCalculationEngine {
  const NutritionCalculationEngine();

  static const int minSafeCalories = 1200;

  /// Mifflin-St Jeor — the formula with the best evidence-based accuracy
  /// among predictive BMR equations for the general population.
  int calculateBmr({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * ageYears;
    switch (sex) {
      case BiologicalSex.male:
        return (base + 5).round();
      case BiologicalSex.female:
        return (base - 161).round();
      case BiologicalSex.other:
        // Midpoint of the male (+5) and female (-161) constants — the
        // formula's only sex-dependent term — rather than defaulting to
        // either, when the user hasn't specified male/female.
        return (base - 78).round();
    }
  }

  int calculateTdee({required int bmr, required ActivityLevel activityLevel}) {
    return (bmr * _activityMultiplier(activityLevel)).round();
  }

  double _activityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  /// Infers an activity multiplier from weekly training frequency when the
  /// user hasn't logged enough real activity data yet. A coarse default,
  /// meant to be superseded by actual step/workout data once available.
  ActivityLevel inferActivityLevel({required int trainingDaysPerWeek}) {
    if (trainingDaysPerWeek <= 1) return ActivityLevel.sedentary;
    if (trainingDaysPerWeek <= 3) return ActivityLevel.light;
    if (trainingDaysPerWeek <= 5) return ActivityLevel.moderate;
    if (trainingDaysPerWeek <= 6) return ActivityLevel.active;
    return ActivityLevel.veryActive;
  }

  NutritionTargets calculateTargets({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required ActivityLevel activityLevel,
    required NutritionGoalType goal,
  }) {
    final bmr = calculateBmr(sex: sex, weightKg: weightKg, heightCm: heightCm, ageYears: ageYears);
    final tdee = calculateTdee(bmr: bmr, activityLevel: activityLevel);

    var calorieTarget = switch (goal) {
      NutritionGoalType.fatLoss => tdee - 500, // ~0.5kg/week — a sustainable, non-extreme deficit
      NutritionGoalType.muscleGain => tdee + 350,
      NutritionGoalType.weightGain => tdee + 500,
      NutritionGoalType.maintain || NutritionGoalType.other => tdee,
    };
    if (calorieTarget < minSafeCalories) calorieTarget = minSafeCalories;

    // Protein scales with weight and goal (higher when building/preserving
    // muscle, including in a deficit); fat gets a fixed ~25% of calories
    // with a floor; carbs take the remainder. All grams are clamped >= 0
    // so an unusually low calorieTarget can never produce a negative macro.
    final proteinPerKg = switch (goal) {
      NutritionGoalType.fatLoss => 2.2,
      NutritionGoalType.muscleGain => 2.0,
      NutritionGoalType.weightGain => 1.8,
      NutritionGoalType.maintain || NutritionGoalType.other => 1.6,
    };
    final proteinGrams = proteinPerKg * weightKg;
    final proteinCalories = proteinGrams * 4;

    final fatCalories = (calorieTarget * 0.25).clamp(0, calorieTarget.toDouble());
    final fatGrams = fatCalories / 9;

    final remainingCalories = (calorieTarget - proteinCalories - fatCalories).clamp(0, double.infinity);
    final carbsGrams = remainingCalories / 4;

    return NutritionTargets(
      bmr: bmr,
      tdee: tdee,
      calorieTarget: calorieTarget,
      proteinGrams: double.parse(proteinGrams.toStringAsFixed(1)),
      carbsGrams: double.parse(carbsGrams.toStringAsFixed(1)),
      fatGrams: double.parse(fatGrams.toStringAsFixed(1)),
      calculationMethod: 'mifflin_st_jeor',
    );
  }
}
