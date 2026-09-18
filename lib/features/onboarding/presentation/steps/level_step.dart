import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_controller.dart';
import '../onboarding_options.dart';
import '../widgets/onboarding_step_scaffold.dart';

class LevelStep extends ConsumerWidget {
  const LevelStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      title: 'Level, location & equipment',
      subtitle: 'A quick self-rating is fine — the baseline test later will refine it if you take it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fitness level', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ChoiceChipGroup(
            options: kFitnessLevelOptions,
            selected: draft.fitnessLevel,
            onSelected: (v) => controller.updateLevelAndLocation(fitnessLevel: v, trainingLocation: draft.trainingLocation ?? 'home'),
          ),
          const SizedBox(height: 20),
          Text('Where do you train?', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ChoiceChipGroup(
            options: kTrainingLocationOptions,
            selected: draft.trainingLocation,
            onSelected: (v) => controller.updateLevelAndLocation(fitnessLevel: draft.fitnessLevel ?? 'beginner', trainingLocation: v),
          ),
          const SizedBox(height: 20),
          Text('Equipment you have access to', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          MultiChoiceChipGroup(
            options: kEquipmentOptions,
            selectedValues: draft.equipment,
            onToggle: controller.toggleEquipment,
          ),
        ],
      ),
    );
  }
}
