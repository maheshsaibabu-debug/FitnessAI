import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/onboarding_controller.dart';
import '../widgets/onboarding_step_scaffold.dart';

class ReviewStep extends ConsumerStatefulWidget {
  const ReviewStep({super.key});

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  bool _submitting = false;
  String? _error;

  Future<void> _finish() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(onboardingControllerProvider.notifier).submit();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong saving your profile: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);

    return OnboardingStepScaffold(
      title: 'Ready to go',
      subtitle: 'This builds your first week of workouts right now, fully offline.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(label: 'Name', value: draft.name),
          _SummaryRow(label: 'Goals', value: draft.goals.isEmpty ? '—' : draft.goals.join(', ')),
          _SummaryRow(label: 'Level', value: draft.fitnessLevel ?? '—'),
          _SummaryRow(label: 'Location', value: draft.trainingLocation ?? '—'),
          _SummaryRow(label: 'Equipment', value: draft.equipment.isEmpty ? 'None' : draft.equipment.join(', ')),
          _SummaryRow(label: 'Schedule', value: '${draft.availabilityDaysPerWeek}x/week, ${draft.availabilityMinutesPerSession} min'),
          if (draft.hasBaselineData) const _SummaryRow(label: 'Baseline', value: 'Recorded'),
          const SizedBox(height: 24),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _submitting ? null : _finish,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Finish and build my plan'),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
