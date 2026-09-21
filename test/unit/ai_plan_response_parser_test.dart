import 'package:fitness_companion/ai/ai_provider.dart';
import 'package:fitness_companion/ai/plan/ai_plan_response_parser.dart';
import 'package:fitness_companion/domain/fitness_engine/fitness_assessment_engine.dart';
import 'package:fitness_companion/domain/nutrition_engine/nutrition_calculation_engine.dart';
import 'package:fitness_companion/domain/workout_engine/exercise_summary.dart';
import 'package:fitness_companion/domain/workout_engine/workout_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';

const _library = [
  ExerciseSummary(id: 'push-up', name: 'Push-up', category: 'bodyweight', primaryMuscles: ['chest'], equipment: ['none'], difficulty: 'beginner'),
  ExerciseSummary(id: 'barbell-squat', name: 'Barbell Squat', category: 'strength', primaryMuscles: ['quadriceps'], equipment: ['barbell'], difficulty: 'advanced'),
  ExerciseSummary(id: 'diamond-push-up', name: 'Diamond Push-up', category: 'bodyweight', primaryMuscles: ['triceps'], equipment: ['none'], difficulty: 'advanced'),
  ExerciseSummary(id: 'plank', name: 'Plank', category: 'core', primaryMuscles: ['core'], equipment: ['none'], difficulty: 'beginner'),
];

const _profile = TrainingProfile(
  fitnessLevel: FitnessLevel.beginner,
  availableEquipment: {'none'},
  daysPerWeek: 2,
  minutesPerSession: 30,
  goals: {'general'},
);

const _nutritionInput = NutritionRequestInput(
  sex: BiologicalSex.male,
  weightKg: 80,
  heightCm: 180,
  ageYears: 30,
  activityLevel: ActivityLevel.moderate,
  goal: NutritionGoalType.maintain,
);

Map<String, Object?> _validWorkout(int dayOffset) => {
      'dayOffset': dayOffset,
      'workoutType': 'strength_full_body',
      'title': 'Day $dayOffset',
      'exercises': [
        {'exerciseId': 'push-up', 'targetSets': 3, 'targetReps': 10, 'targetDurationSeconds': null, 'restSeconds': 60},
      ],
    };

Map<String, Object?> _validNutrition() => {
      'calorieTarget': 2200,
      'proteinGrams': 150,
      'carbsGrams': 220,
      'fatGrams': 70,
    };

void main() {
  const parser = AiPlanResponseParser();

  test('parses a fully valid response into a matching GeneratedPlan and NutritionTargets', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [_validWorkout(0), _validWorkout(1)],
        'nutrition': _validNutrition(),
      },
      model: 'test-model',
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    expect(result.plan.workouts, hasLength(2));
    expect(result.plan.workouts.first.exercises.single.exerciseId, 'push-up');
    expect(result.nutrition.calorieTarget, 2200);
    expect(result.model, 'test-model');
  });

  test('drops an exercise requiring equipment the user does not have', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [
          {
            'dayOffset': 0,
            'workoutType': 'strength_full_body',
            'exercises': [
              {'exerciseId': 'barbell-squat', 'targetSets': 3, 'targetReps': 8, 'restSeconds': 90},
              {'exerciseId': 'push-up', 'targetSets': 3, 'targetReps': 10, 'restSeconds': 60},
            ],
          },
          _validWorkout(1),
        ],
        'nutrition': _validNutrition(),
      },
      model: null,
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    final exerciseIds = result.plan.workouts.expand((w) => w.exercises).map((e) => e.exerciseId);
    expect(exerciseIds, isNot(contains('barbell-squat')));
    expect(exerciseIds, contains('push-up'));
  });

  test('drops an exercise above the user\'s fitness level', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [
          {
            'dayOffset': 0,
            'workoutType': 'strength_full_body',
            'exercises': [
              {'exerciseId': 'diamond-push-up', 'targetSets': 3, 'targetReps': 8, 'restSeconds': 60},
              {'exerciseId': 'push-up', 'targetSets': 3, 'targetReps': 10, 'restSeconds': 60},
            ],
          },
          _validWorkout(1),
        ],
        'nutrition': _validNutrition(),
      },
      model: null,
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    final exerciseIds = result.plan.workouts.expand((w) => w.exercises).map((e) => e.exerciseId);
    expect(exerciseIds, isNot(contains('diamond-push-up')));
  });

  test('drops a hallucinated exercise id that is not in the library', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [
          {
            'dayOffset': 0,
            'workoutType': 'strength_full_body',
            'exercises': [
              {'exerciseId': 'made-up-exercise', 'targetSets': 3, 'targetReps': 8, 'restSeconds': 60},
              {'exerciseId': 'push-up', 'targetSets': 3, 'targetReps': 10, 'restSeconds': 60},
            ],
          },
          _validWorkout(1),
        ],
        'nutrition': _validNutrition(),
      },
      model: null,
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    final exerciseIds = result.plan.workouts.expand((w) => w.exercises).map((e) => e.exerciseId);
    expect(exerciseIds, isNot(contains('made-up-exercise')));
  });

  test('throws when the response has fewer valid days than requested', () {
    expect(
      () => parser.parse(
        rawPlan: {
          'workouts': [_validWorkout(0)], // profile wants 2 days
          'nutrition': _validNutrition(),
        },
        model: null,
        trainingProfile: _profile,
        library: _library,
        nutritionInput: _nutritionInput,
      ),
      throwsA(isA<AiProviderException>()),
    );
  });

  test('clamps an unsafe low calorie target to the safety floor', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [_validWorkout(0), _validWorkout(1)],
        'nutrition': {'calorieTarget': 400, 'proteinGrams': 50, 'carbsGrams': 20, 'fatGrams': 10},
      },
      model: null,
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    expect(result.nutrition.calorieTarget, NutritionCalculationEngine.minSafeCalories);
  });

  test('clamps negative macros to zero rather than propagating them', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [_validWorkout(0), _validWorkout(1)],
        'nutrition': {'calorieTarget': 2200, 'proteinGrams': -10, 'carbsGrams': 220, 'fatGrams': 70},
      },
      model: null,
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    expect(result.nutrition.proteinGrams, 0);
  });

  test('throws when nutrition numbers are missing entirely', () {
    expect(
      () => parser.parse(
        rawPlan: {
          'workouts': [_validWorkout(0), _validWorkout(1)],
          'nutrition': {'calorieTarget': 2200},
        },
        model: null,
        trainingProfile: _profile,
        library: _library,
        nutritionInput: _nutritionInput,
      ),
      throwsA(isA<AiProviderException>()),
    );
  });

  test('requires exactly one of targetReps/targetDurationSeconds, not both or neither', () {
    final result = parser.parse(
      rawPlan: {
        'workouts': [
          {
            'dayOffset': 0,
            'workoutType': 'strength_full_body',
            'exercises': [
              {'exerciseId': 'push-up', 'targetSets': 3, 'targetReps': 10, 'targetDurationSeconds': 30, 'restSeconds': 60},
              {'exerciseId': 'plank', 'targetSets': 3, 'targetReps': null, 'targetDurationSeconds': null, 'restSeconds': 60},
              // A third, well-formed exercise keeps this day non-empty so
              // it isn't dropped wholesale before the malformed entries
              // above can be individually checked.
              {'exerciseId': 'plank', 'targetSets': 3, 'targetReps': null, 'targetDurationSeconds': 30, 'restSeconds': 60},
            ],
          },
          _validWorkout(1),
        ],
        'nutrition': _validNutrition(),
      },
      model: null,
      trainingProfile: _profile,
      library: _library,
      nutritionInput: _nutritionInput,
    );

    final dayZero = result.plan.workouts.firstWhere((w) => w.dayOffset == 0);
    expect(dayZero.exercises, hasLength(1)); // only the well-formed plank survives
    expect(dayZero.exercises.single.targetDurationSeconds, 30);
  });
}
