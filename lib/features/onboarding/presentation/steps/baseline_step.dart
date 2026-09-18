import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_controller.dart';
import '../widgets/onboarding_step_scaffold.dart';

/// Product spec §17: a lightweight self-test, entirely optional. Anything
/// left blank here is simply omitted — [ProfileRepository] falls back to
/// the self-reported level from the previous step when no baseline data
/// is present at all.
class BaselineStep extends ConsumerStatefulWidget {
  const BaselineStep({super.key});

  @override
  ConsumerState<BaselineStep> createState() => _BaselineStepState();
}

class _BaselineStepState extends ConsumerState<BaselineStep> {
  late final TextEditingController _pushUps;
  late final TextEditingController _squats;
  late final TextEditingController _pullUps;
  late final TextEditingController _plank;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(onboardingControllerProvider);
    _pushUps = TextEditingController(text: draft.baselinePushUps?.toString() ?? '');
    _squats = TextEditingController(text: draft.baselineSquats?.toString() ?? '');
    _pullUps = TextEditingController(text: draft.baselinePullUps?.toString() ?? '');
    _plank = TextEditingController(text: draft.baselinePlankSeconds?.toString() ?? '');
  }

  @override
  void dispose() {
    _pushUps.dispose();
    _squats.dispose();
    _pullUps.dispose();
    _plank.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(onboardingControllerProvider.notifier);
    final draft = ref.watch(onboardingControllerProvider);

    void update() {
      controller.updateBaseline(
        pushUps: int.tryParse(_pushUps.text),
        squats: int.tryParse(_squats.text),
        pullUps: int.tryParse(_pullUps.text),
        plankSeconds: int.tryParse(_plank.text),
      );
    }

    return OnboardingStepScaffold(
      title: 'Fitness baseline (optional)',
      subtitle: 'Max reps in one set, or plank hold time. Skip anything you\'d rather not test right now.',
      child: Column(
        children: [
          _CountField(label: 'Push-ups (max reps)', controller: _pushUps, onChanged: (_) => update()),
          const SizedBox(height: 16),
          _CountField(label: 'Squats (max reps)', controller: _squats, onChanged: (_) => update()),
          const SizedBox(height: 16),
          _CountField(label: 'Pull-ups (max reps)', controller: _pullUps, onChanged: (_) => update()),
          const SizedBox(height: 16),
          _CountField(label: 'Plank hold (seconds)', controller: _plank, onChanged: (_) => update()),
          if (draft.hasBaselineData) ...[
            const SizedBox(height: 20),
            Text(
              'This will refine your starting level beyond the self-rating from the last step.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _CountField extends StatelessWidget {
  const _CountField({required this.label, required this.controller, required this.onChanged});

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}
