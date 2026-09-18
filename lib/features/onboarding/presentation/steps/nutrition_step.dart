import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_controller.dart';
import '../onboarding_options.dart';
import '../widgets/onboarding_step_scaffold.dart';

const _restrictionOptions = [
  ('dairy_free', 'Dairy-free'),
  ('gluten_free', 'Gluten-free'),
  ('nut_free', 'Nut-free'),
  ('shellfish_free', 'Shellfish-free'),
  ('halal', 'Halal'),
  ('kosher', 'Kosher'),
];

class NutritionStep extends ConsumerWidget {
  const NutritionStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      title: 'Nutrition preferences',
      subtitle: 'Used to tailor meal suggestions later — your calorie/macro targets are calculated regardless.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diet', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ChoiceChipGroup(
            options: kDietaryPreferenceOptions,
            selected: draft.dietaryPreference,
            onSelected: controller.updateDietaryPreference,
          ),
          const SizedBox(height: 20),
          Text('Restrictions (optional)', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          MultiChoiceChipGroup(
            options: _restrictionOptions,
            selectedValues: draft.dietaryRestrictions,
            onToggle: controller.toggleDietaryRestriction,
          ),
        ],
      ),
    );
  }
}
