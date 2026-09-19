import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../data/local/health_repository.dart';
import '../../../data/repositories/repository_providers.dart';
import '../application/tracking_providers.dart';

const _defaultStepsTarget = 8000;

/// "Track" (product spec §22-23, §38-39): steps and weight. Steps come
/// from HealthKit/Health Connect when available and permitted, with
/// manual entry always offered as the offline-safe fallback — the app
/// never assumes a health platform will actually deliver data (denied
/// permission, no plugin registered, simulator with no Health data all
/// degrade the same way: show manual entry, not an error).
class TrackScreen extends ConsumerWidget {
  const TrackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _StepsCard(),
          SizedBox(height: 16),
          _WeightCard(),
        ],
      ),
    );
  }
}

class _StepsCard extends ConsumerWidget {
  const _StepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaysSteps = ref.watch(todaysStepsProvider);
    final connection = ref.watch(healthConnectionControllerProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Steps', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Center(
              child: todaysSteps.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, st) => Text('Could not load steps: $e'),
                data: (record) => _StepsRing(record: record),
              ),
            ),
            if (todaysSteps.valueOrNull != null)
              Center(
                child: Text(
                  'Source: ${todaysSteps.value!.source}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            connection.when(
              loading: () => const SizedBox.shrink(),
              error: (e, st) => Text('Health connection unavailable: $e'),
              data: (status) => _ConnectionRow(status: status),
            ),
            const SizedBox(height: 12),
            const _ManualStepsEntry(),
          ],
        ),
      ),
    );
  }
}

class _StepsRing extends StatelessWidget {
  const _StepsRing({required this.record});
  final StepRecord? record;

  @override
  Widget build(BuildContext context) {
    final steps = record?.steps ?? 0;
    final target = record?.target ?? _defaultStepsTarget;
    final progress = target <= 0 ? 0.0 : (steps / target).clamp(0.0, 1.0);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                record == null ? '—' : '$steps',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text('of $target', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionRow extends ConsumerWidget {
  const _ConnectionRow({required this.status});
  final HealthPermissionStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(healthConnectionControllerProvider.notifier);
    switch (status) {
      case HealthPermissionStatus.granted:
        return OutlinedButton.icon(
          onPressed: controller.syncNow,
          icon: const Icon(Icons.sync),
          label: const Text('Sync from Health'),
        );
      case HealthPermissionStatus.denied:
        return Text(
          'Health permission was denied — steps won\'t sync automatically. Log them manually below, or reconnect from Settings.',
          style: Theme.of(context).textTheme.bodySmall,
        );
      case HealthPermissionStatus.unavailable:
        return OutlinedButton(
          onPressed: controller.requestAndSync,
          child: const Text('Connect Health'),
        );
    }
  }
}

class _ManualStepsEntry extends ConsumerStatefulWidget {
  const _ManualStepsEntry();

  @override
  ConsumerState<_ManualStepsEntry> createState() => _ManualStepsEntryState();
}

class _ManualStepsEntryState extends ConsumerState<_ManualStepsEntry> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final steps = int.tryParse(_controller.text);
    if (steps == null) return;
    final profile = await ref.read(profileRepositoryProvider).activeProfileOnce();
    if (profile == null) return;
    await ref.read(stepsRepositoryProvider).upsertSteps(userId: profile.id, steps: steps, source: 'manual');
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Log steps manually'),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _WeightCard extends ConsumerWidget {
  const _WeightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = ref.watch(latestWeightProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Weight', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            latest.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, st) => Text('Could not load weight: $e'),
              data: (log) => Text(
                log == null ? 'No entries yet' : '${log.weightKg.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _showLogWeightDialog(context, ref),
              child: const Text('Log weight'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogWeightDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final weight = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (weight == null) return;

    final profile = await ref.read(profileRepositoryProvider).activeProfileOnce();
    if (profile == null) return;
    await ref.read(weightRepositoryProvider).logWeight(userId: profile.id, weightKg: weight);
  }
}
