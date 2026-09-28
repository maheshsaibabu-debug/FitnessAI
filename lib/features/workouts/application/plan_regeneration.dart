import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ai/ai_providers.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/repository_providers.dart';

/// The outcome of [regeneratePlanAndDiet] — `source` is 'ai' or
/// 'deterministic', shown to the user so a fallback regenerate never
/// masquerades as an AI one (same rule as the rest of the AI surface).
class PlanRegenerationResult {
  const PlanRegenerationResult({required this.source});
  final String source;
}

/// Regenerates the upcoming workout plan and nutrition targets against the
/// user's current saved profile — the same operation the Plan screen's
/// "Regenerate" button runs, extracted here so the Profile screen's goal
/// edit can trigger it too after a target weight/date change, without
/// duplicating the AI-first/deterministic-fallback wiring.
Future<PlanRegenerationResult?> regeneratePlanAndDiet(WidgetRef ref) async {
  final profileRepository = ref.read(profileRepositoryProvider);
  final profile = await profileRepository.activeProfileOnce();
  final trainingProfile = await profileRepository.currentTrainingProfile();
  if (profile == null || trainingProfile == null) return null;

  final latestWeight = await ref.read(weightRepositoryProvider).latestOnce(profile.id);
  final primaryGoal = await profileRepository.primaryGoalOnce(profile.id);
  final nutritionInput = nutritionRequestInputForProfile(
    profile,
    weightKg: latestWeight?.weightKg ?? 70,
    primaryGoal: primaryGoal,
  );

  final exerciseLibrarySeeder = ref.read(exerciseLibrarySeederProvider);
  await exerciseLibrarySeeder.seedIfEmpty();
  final library = await exerciseLibrarySeeder.loadSummaries();

  final result = await ref.read(planGenerationServiceProvider).generate(
        trainingProfile: trainingProfile,
        library: library,
        nutritionInput: nutritionInput,
      );

  await ref.read(workoutPlanRepositoryProvider).persistUpcomingPlanReplacement(
        userId: profile.id,
        generated: result.plan,
        from: DateTime.now(),
      );
  await profileRepository.updateNutritionTargets(profile.id, result.nutrition);

  return PlanRegenerationResult(source: result.source);
}
