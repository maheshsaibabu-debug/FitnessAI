import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/fitness_engine/fitness_assessment_engine.dart';
import '../../domain/nutrition_engine/nutrition_calculation_engine.dart';
import '../../domain/workout_engine/exercise_summary.dart';
import '../../domain/workout_engine/workout_generation_engine.dart';
import '../ai_provider.dart' show AiProviderException;
import 'ai_plan_response_parser.dart';

/// Calls supabase/functions/ai-plan-generator and hands the raw response
/// to [AiPlanResponseParser] for validation — this class owns only the
/// network call and request shape, matching [CloudAiProvider]'s role for
/// Coach chat (ai/providers/cloud_ai_provider.dart). See
/// [AiPlanResponseParser]'s doc comment for what happens to the response.
class AiPlanProvider {
  AiPlanProvider({required this.functionName, this.parser = const AiPlanResponseParser()});

  final String functionName;
  final AiPlanResponseParser parser;

  Future<AiGeneratedPlan> generate({
    required TrainingProfile trainingProfile,
    required List<ExerciseSummary> library,
    required NutritionRequestInput nutritionInput,
  }) async {
    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: {
          'profile': {
            'fitnessLevel': _levelName(trainingProfile.fitnessLevel),
            'availableEquipment': trainingProfile.availableEquipment.toList(),
            'daysPerWeek': trainingProfile.daysPerWeek,
            'minutesPerSession': trainingProfile.minutesPerSession,
            'goals': trainingProfile.goals.toList(),
          },
          'nutritionInput': nutritionInput.toJson(),
          'library': library
              .map((e) => {
                    'id': e.id,
                    'name': e.name,
                    'category': e.category,
                    'primaryMuscles': e.primaryMuscles,
                    'equipment': e.equipment,
                    'difficulty': e.difficulty,
                  })
              .toList(),
        },
      );
    } catch (e) {
      throw AiProviderException('Could not reach the plan generator', e);
    }

    if (response.status != 200) {
      throw AiProviderException('Plan generator returned status ${response.status}');
    }

    final data = response.data;
    if (data is! Map || data['plan'] is! Map) {
      throw AiProviderException('Plan generator returned an unexpected response shape');
    }

    return parser.parse(
      rawPlan: data['plan'] as Map,
      model: data['model'] as String?,
      trainingProfile: trainingProfile,
      library: library,
      nutritionInput: nutritionInput,
    );
  }

  String _levelName(FitnessLevel level) => switch (level) {
        FitnessLevel.beginner => 'beginner',
        FitnessLevel.intermediate => 'intermediate',
        FitnessLevel.advanced => 'advanced',
      };
}
