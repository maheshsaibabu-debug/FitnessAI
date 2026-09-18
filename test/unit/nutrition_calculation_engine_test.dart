import 'package:fitness_companion/domain/nutrition_engine/nutrition_calculation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = const NutritionCalculationEngine();

  test('Mifflin-St Jeor BMR matches the textbook formula for a male', () {
    // 30yo male, 80kg, 180cm: 10*80 + 6.25*180 - 5*30 + 5 = 800+1125-150+5 = 1780
    final bmr = engine.calculateBmr(sex: BiologicalSex.male, weightKg: 80, heightCm: 180, ageYears: 30);
    expect(bmr, 1780);
  });

  test('Mifflin-St Jeor BMR matches the textbook formula for a female', () {
    // 28yo female, 60kg, 165cm: 10*60 + 6.25*165 - 5*28 - 161 = 600+1031.25-140-161 = 1330.25 -> 1330
    final bmr = engine.calculateBmr(sex: BiologicalSex.female, weightKg: 60, heightCm: 165, ageYears: 28);
    expect(bmr, 1330);
  });

  test('TDEE scales BMR by the activity multiplier', () {
    final tdee = engine.calculateTdee(bmr: 1780, activityLevel: ActivityLevel.moderate);
    expect(tdee, (1780 * 1.55).round());
  });

  test('fat loss target is a moderate deficit below TDEE, never below the safety floor', () {
    final targets = engine.calculateTargets(
      sex: BiologicalSex.male,
      weightKg: 80,
      heightCm: 180,
      ageYears: 30,
      activityLevel: ActivityLevel.light,
      goal: NutritionGoalType.fatLoss,
    );
    expect(targets.calorieTarget, targets.tdee - 500);
    expect(targets.calorieTarget, greaterThanOrEqualTo(NutritionCalculationEngine.minSafeCalories));
  });

  test('an extreme low-TDEE deficit is clamped to the safety floor, never below it', () {
    final targets = engine.calculateTargets(
      sex: BiologicalSex.female,
      weightKg: 45,
      heightCm: 150,
      ageYears: 60,
      activityLevel: ActivityLevel.sedentary,
      goal: NutritionGoalType.fatLoss,
    );
    expect(targets.calorieTarget, NutritionCalculationEngine.minSafeCalories);
  });

  test('macros are non-negative and sum to roughly the calorie target', () {
    final targets = engine.calculateTargets(
      sex: BiologicalSex.male,
      weightKg: 90,
      heightCm: 185,
      ageYears: 25,
      activityLevel: ActivityLevel.active,
      goal: NutritionGoalType.muscleGain,
    );
    expect(targets.proteinGrams, greaterThan(0));
    expect(targets.carbsGrams, greaterThanOrEqualTo(0));
    expect(targets.fatGrams, greaterThan(0));

    final reconstructedCalories = targets.proteinGrams * 4 + targets.carbsGrams * 4 + targets.fatGrams * 9;
    expect(reconstructedCalories, closeTo(targets.calorieTarget.toDouble(), 5));
  });

  test('inferActivityLevel scales with training frequency', () {
    expect(engine.inferActivityLevel(trainingDaysPerWeek: 0), ActivityLevel.sedentary);
    expect(engine.inferActivityLevel(trainingDaysPerWeek: 3), ActivityLevel.light);
    expect(engine.inferActivityLevel(trainingDaysPerWeek: 5), ActivityLevel.moderate);
    expect(engine.inferActivityLevel(trainingDaysPerWeek: 7), ActivityLevel.veryActive);
  });
}
