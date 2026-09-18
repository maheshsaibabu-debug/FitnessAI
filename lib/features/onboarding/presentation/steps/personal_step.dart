import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_controller.dart';
import '../widgets/onboarding_step_scaffold.dart';

class PersonalStep extends ConsumerStatefulWidget {
  const PersonalStep({super.key});

  @override
  ConsumerState<PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends ConsumerState<PersonalStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingControllerProvider);
    _nameController = TextEditingController(text: draft.name);
    _heightController = TextEditingController(text: draft.heightCm?.toStringAsFixed(0) ?? '');
    _weightController = TextEditingController(text: draft.weightKg?.toStringAsFixed(1) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingStepScaffold(
      title: 'About you',
      subtitle: 'This shapes your plan and calorie estimate — nothing here is shared without your say-so.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: controller.updateName,
          ),
          const SizedBox(height: 20),
          Text('Sex', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ChoiceChipGroup(
            options: const [('male', 'Male'), ('female', 'Female'), ('other', 'Other / prefer not to say')],
            selected: draft.sex,
            onSelected: controller.updateSex,
          ),
          const SizedBox(height: 20),
          Text('Date of birth', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: draft.dateOfBirth ?? DateTime(now.year - 30),
                firstDate: DateTime(now.year - 100),
                lastDate: DateTime(now.year - 13),
              );
              if (picked != null) controller.updateDateOfBirth(picked);
            },
            child: Text(draft.dateOfBirth == null
                ? 'Select date of birth'
                : '${draft.dateOfBirth!.year}-${draft.dateOfBirth!.month.toString().padLeft(2, '0')}-${draft.dateOfBirth!.day.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Height (cm)'),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) controller.updateHeightCm(parsed);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) controller.updateWeightKg(parsed);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
