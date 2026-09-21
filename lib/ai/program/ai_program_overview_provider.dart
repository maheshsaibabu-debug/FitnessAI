import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/program_engine/program_trajectory_engine.dart';
import '../ai_provider.dart' show AiProviderException;
import 'program_overview_input.dart';

/// Calls supabase/functions/ai-program-overview — the narrative layer
/// over a [ProgramTrajectory] the client already computed deterministically
/// (see docs/AI_ARCHITECTURE.md's division of responsibility). This class
/// never sees the OpenRouter key or picks the model; it just ships the
/// real numbers and gets prose back.
class AiProgramOverviewProvider {
  AiProgramOverviewProvider({required this.functionName});

  final String functionName;

  Future<ProgramOverviewResult> generate(ProgramOverviewInput input) async {
    final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: {
          'profile': {
            'name': input.name,
            'fitnessLevel': input.fitnessLevel,
            'goals': input.goals.toList(),
            if (input.dietaryPreference != null) 'dietaryPreference': input.dietaryPreference,
            'dietaryRestrictions': input.dietaryRestrictions.toList(),
          },
          'trajectory': _trajectoryJson(input.trajectory),
          'nutrition': {
            'calorieTarget': input.nutrition.calorieTarget,
            'proteinGrams': input.nutrition.proteinGrams,
            'carbsGrams': input.nutrition.carbsGrams,
            'fatGrams': input.nutrition.fatGrams,
          },
          'weeklyPlan': input.weeklyPlan
              .map((d) => {'title': d.title, 'workoutType': d.workoutType, 'exercises': d.exerciseNames})
              .toList(),
        },
      );
    } catch (e) {
      throw AiProviderException('Could not reach the program overview generator', e);
    }

    if (response.status != 200) {
      throw AiProviderException('Program overview generator returned status ${response.status}');
    }

    final data = response.data;
    if (data is! Map || data['overview'] is! String) {
      throw AiProviderException('Program overview generator returned an unexpected response shape');
    }

    return ProgramOverviewResult(overview: data['overview'] as String, source: 'ai', model: data['model'] as String?);
  }

  Map<String, Object?> _trajectoryJson(ProgramTrajectory t) => {
        'startWeightKg': t.startWeightKg,
        'goalWeightKg': t.goalWeightKg,
        'effectiveTargetDate': t.effectiveTargetDate.toIso8601String(),
        'wasAdjusted': t.wasAdjusted,
        'adjustmentReason': t.adjustmentReason,
        'weeklyRateKg': t.weeklyRateKg,
        'milestones': t.milestones
            .map((m) => {'date': m.date.toIso8601String(), 'weightKg': m.weightKg, 'label': m.label})
            .toList(),
      };
}
