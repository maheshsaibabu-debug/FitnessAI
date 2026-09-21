import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/program_engine/program_trajectory_engine.dart';
import '../application/program_controller.dart';

/// "Your Program" — a goal weight + target date turned into a real,
/// safety-capped trajectory ([ProgramTrajectoryEngine]) and narrated
/// (AI-first, deterministic-fallback — [ProgramController]) into a full
/// overview: trajectory, this week's real plan, nutrition targets, and a
/// weekly tracking checklist. Every number here is real; only the prose
/// organizing it is generated.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerState = ref.watch(programControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Program')),
      body: controllerState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $e'))),
        data: (state) {
          if (!state.hasGoal) return const _GoalForm();
          return _ProgramView(state: state);
        },
      ),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm();

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _weightController = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month + 3, now.day),
      firstDate: now.add(const Duration(days: 14)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0 || _targetDate == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(programControllerProvider.notifier).setGoal(goalWeightKg: weight, targetDate: _targetDate!);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set your goal', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'A target weight and date turns your plan into a real trajectory — with the pace kept to a safe rate automatically.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Target weight (kg)'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(_targetDate == null ? 'Pick a target date' : DateFormat.yMMMd().format(_targetDate!)),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Build my program'),
          ),
        ],
      ),
    );
  }
}

class _ProgramView extends ConsumerWidget {
  const _ProgramView({required this.state});
  final ProgramState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.read(programControllerProvider.notifier).generateOverview(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Goal', style: Theme.of(context).textTheme.titleMedium)),
                      Text('${state.goalWeightKg!.toStringAsFixed(1)} kg by ${DateFormat.yMMMd().format(state.targetDate!)}'),
                    ],
                  ),
                  if (state.trajectory != null) ...[
                    const SizedBox(height: 16),
                    if (state.trajectory!.wasAdjusted)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          state.trajectory!.adjustmentReason ?? 'Your timeline was adjusted to a safe pace.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                        ),
                      ),
                    for (final m in state.trajectory!.milestones) _MilestoneRow(milestone: m),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (state.error != null && state.error!.isNotEmpty)
            Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(state.error!, style: TextStyle(color: scheme.onErrorContainer)),
              ),
            ),
          if (state.overview != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.overview!.overview, style: Theme.of(context).textTheme.bodyMedium),
                    if (state.overview!.source == 'deterministic')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Offline overview',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: OutlinedButton.icon(
              onPressed: state.isGenerating ? null : () => ref.read(programControllerProvider.notifier).generateOverview(),
              icon: state.isGenerating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh),
              label: Text(state.overview == null ? 'Generate overview' : 'Regenerate overview'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.milestone});
  final ProgramMilestone milestone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(milestone.label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(DateFormat.yMMMd().format(milestone.date), style: Theme.of(context).textTheme.bodySmall)),
          Text('${milestone.weightKg.toStringAsFixed(1)} kg', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
