import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_controller.dart';
import '../onboarding_options.dart';
import '../widgets/onboarding_step_scaffold.dart';

class AvailabilityStep extends ConsumerWidget {
  const AvailabilityStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    void apply({int? days, int? minutes, String? time}) {
      controller.updateAvailability(
        daysPerWeek: days ?? draft.availabilityDaysPerWeek,
        minutesPerSession: minutes ?? draft.availabilityMinutesPerSession,
        preferredTimeOfDay: time ?? draft.preferredTimeOfDay,
      );
    }

    return OnboardingStepScaffold(
      title: 'How much time do you have?',
      subtitle: 'Be realistic — a plan you can actually keep beats an ambitious one you can\'t.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${draft.availabilityDaysPerWeek} day${draft.availabilityDaysPerWeek == 1 ? '' : 's'} per week',
              style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: draft.availabilityDaysPerWeek.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '${draft.availabilityDaysPerWeek}',
            onChanged: (v) => apply(days: v.round()),
          ),
          const SizedBox(height: 12),
          Text('${draft.availabilityMinutesPerSession} minutes per session', style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: draft.availabilityMinutesPerSession.toDouble(),
            min: 10,
            max: 90,
            divisions: 16,
            label: '${draft.availabilityMinutesPerSession}',
            onChanged: (v) => apply(minutes: v.round()),
          ),
          const SizedBox(height: 20),
          Text('Preferred time of day', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ChoiceChipGroup(
            options: kPreferredTimeOptions,
            selected: draft.preferredTimeOfDay,
            onSelected: (v) => apply(time: v),
          ),
        ],
      ),
    );
  }
}
