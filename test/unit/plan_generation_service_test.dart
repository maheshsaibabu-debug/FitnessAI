import 'package:fitness_companion/ai/ai_provider.dart' show AiProviderException;
import 'package:fitness_companion/ai/plan/ai_plan_provider.dart';
import 'package:fitness_companion/ai/plan/ai_plan_response_parser.dart';
import 'package:fitness_companion/ai/plan/plan_generation_service.dart';
import 'package:fitness_companion/domain/fitness_engine/fitness_assessment_engine.dart';
import 'package:fitness_companion/domain/nutrition_engine/nutrition_calculation_engine.dart';
import 'package:fitness_companion/domain/workout_engine/exercise_summary.dart';
import 'package:fitness_companion/domain/workout_engine/workout_generation_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAiPlanProvider extends Mock implements AiPlanProvider {}

void main() {
  late _MockAiPlanProvider aiPlanProvider;
  late PlanGenerationService service;

  const plan = GeneratedPlan(workouts: []);
  const nutrition = NutritionTargets(
    bmr: 1600,
    tdee: 2200,
    calorieTarget: 2000,
    proteinGrams: 150,
    carbsGrams: 200,
    fatGrams: 65,
    calculationMethod: 'mifflin_st_jeor',
  );

  TrainingProfile profile({Set<String> goals = const {'fat_loss'}}) =>
      TrainingProfile(
        fitnessLevel: FitnessLevel.beginner,
        availableEquipment: const {'none'},
        daysPerWeek: 3,
        minutesPerSession: 30,
        goals: goals,
      );

  const nutritionInput = NutritionRequestInput(
    sex: BiologicalSex.male,
    weightKg: 80,
    heightCm: 178,
    ageYears: 30,
    activityLevel: ActivityLevel.moderate,
    goal: NutritionGoalType.fatLoss,
  );

  setUpAll(() {
    registerFallbackValue(
      const TrainingProfile(
        fitnessLevel: FitnessLevel.beginner,
        availableEquipment: {},
        daysPerWeek: 3,
        minutesPerSession: 30,
      ),
    );
    registerFallbackValue(<ExerciseSummary>[]);
    registerFallbackValue(
      const NutritionRequestInput(
        sex: BiologicalSex.male,
        weightKg: 80,
        heightCm: 178,
        ageYears: 30,
        activityLevel: ActivityLevel.moderate,
        goal: NutritionGoalType.fatLoss,
      ),
    );
  });

  setUp(() {
    aiPlanProvider = _MockAiPlanProvider();
    service = PlanGenerationService(aiPlanProvider: aiPlanProvider);
    when(
      () => aiPlanProvider.generate(
        trainingProfile: any(named: 'trainingProfile'),
        library: any(named: 'library'),
        nutritionInput: any(named: 'nutritionInput'),
      ),
    ).thenAnswer(
      (_) async => const AiGeneratedPlan(
        plan: plan,
        nutrition: nutrition,
        model: 'qwen/qwen3.7-flash',
      ),
    );
  });

  test(
    'calls the AI provider once, then serves identical repeat requests from cache',
    () async {
      await service.generate(
        trainingProfile: profile(),
        library: const [],
        nutritionInput: nutritionInput,
      );
      final second = await service.generate(
        trainingProfile: profile(),
        library: const [],
        nutritionInput: nutritionInput,
      );

      verify(
        () => aiPlanProvider.generate(
          trainingProfile: any(named: 'trainingProfile'),
          library: any(named: 'library'),
          nutritionInput: any(named: 'nutritionInput'),
        ),
      ).called(1);
      expect(second.source, 'ai');
      expect(second.model, 'qwen/qwen3.7-flash');
    },
  );

  test('re-calls the AI provider when the goals change', () async {
    await service.generate(
      trainingProfile: profile(goals: {'fat_loss'}),
      library: const [],
      nutritionInput: nutritionInput,
    );
    await service.generate(
      trainingProfile: profile(goals: {'muscle_gain'}),
      library: const [],
      nutritionInput: nutritionInput,
    );

    verify(
      () => aiPlanProvider.generate(
        trainingProfile: any(named: 'trainingProfile'),
        library: any(named: 'library'),
        nutritionInput: any(named: 'nutritionInput'),
      ),
    ).called(2);
  });

  test(
    're-calls the AI provider when a profile constraint (daysPerWeek) changes',
    () async {
      await service.generate(
        trainingProfile: profile(),
        library: const [],
        nutritionInput: nutritionInput,
      );
      final changedProfile = TrainingProfile(
        fitnessLevel: FitnessLevel.beginner,
        availableEquipment: const {'none'},
        daysPerWeek: 5,
        minutesPerSession: 30,
        goals: const {'fat_loss'},
      );
      await service.generate(
        trainingProfile: changedProfile,
        library: const [],
        nutritionInput: nutritionInput,
      );

      verify(
        () => aiPlanProvider.generate(
          trainingProfile: any(named: 'trainingProfile'),
          library: any(named: 'library'),
          nutritionInput: any(named: 'nutritionInput'),
        ),
      ).called(2);
    },
  );

  test(
    'never caches a fallback, so a transient AI failure does not poison later identical requests',
    () async {
      when(
        () => aiPlanProvider.generate(
          trainingProfile: any(named: 'trainingProfile'),
          library: any(named: 'library'),
          nutritionInput: any(named: 'nutritionInput'),
        ),
      ).thenThrow(AiProviderException('offline'));

      final failed = await service.generate(
        trainingProfile: profile(),
        library: const [],
        nutritionInput: nutritionInput,
      );
      expect(failed.source, 'deterministic');

      when(
        () => aiPlanProvider.generate(
          trainingProfile: any(named: 'trainingProfile'),
          library: any(named: 'library'),
          nutritionInput: any(named: 'nutritionInput'),
        ),
      ).thenAnswer(
        (_) async => const AiGeneratedPlan(
          plan: plan,
          nutrition: nutrition,
          model: 'qwen/qwen3.7-flash',
        ),
      );
      final recovered = await service.generate(
        trainingProfile: profile(),
        library: const [],
        nutritionInput: nutritionInput,
      );
      expect(recovered.source, 'ai');
    },
  );
}
