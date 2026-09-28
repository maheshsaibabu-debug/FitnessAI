import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../onboarding/presentation/onboarding_options.dart';
import '../../tracking/application/tracking_providers.dart';
import '../../workouts/application/plan_regeneration.dart';
import '../application/profile_providers.dart';

Set<String> _parseJsonList(String json) {
  if (json.isEmpty) return {};
  return (jsonDecode(json) as List).map((v) => v.toString()).toSet();
}

String _labelFor(List<(String value, String label)> options, String? value) {
  if (value == null) return 'Not set';
  for (final (v, label) in options) {
    if (v == value) return label;
  }
  return value;
}

/// Everything collected across the seven onboarding steps, plus the goal's
/// target weight/date, in one place — with an edit entry point for each
/// editable section. Every value shown is read straight from the same
/// tables onboarding wrote to; nothing here is recomputed or invented.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final latestWeight = ref.watch(latestWeightProvider);
    final primaryGoal = ref.watch(primaryGoalProvider);
    final baseline = ref.watch(latestBaselineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () => context.push('/profile/edit'),
          ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Could not load profile: $e'))),
        data: (p) {
          if (p == null) return const Center(child: Text('No profile found.'));
          final equipment = _parseJsonList(p.equipmentJson);
          final restrictions = _parseJsonList(p.dietaryRestrictionsJson);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(p.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Personal',
                rows: [
                  _fieldRow('Sex', _labelFor(kSexOptions, p.sex)),
                  _fieldRow(
                    'Date of birth',
                    p.dateOfBirth == null ? 'Not set' : DateFormat.yMMMd().format(p.dateOfBirth!),
                  ),
                  _fieldRow('Height', p.heightCm == null ? 'Not set' : '${p.heightCm!.toStringAsFixed(0)} cm'),
                  _fieldRow(
                    'Current weight',
                    latestWeight.valueOrNull == null ? 'Not logged yet' : '${latestWeight.value!.weightKg.toStringAsFixed(1)} kg',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Goal',
                rows: [
                  _fieldRow('Focus', primaryGoal.valueOrNull == null ? 'Not set' : _labelFor(kGoalOptions, primaryGoal.value!.goalType)),
                  _fieldRow(
                    'Target weight',
                    primaryGoal.valueOrNull?.targetValue == null ? 'Not set' : '${primaryGoal.value!.targetValue!.toStringAsFixed(1)} kg',
                  ),
                  _fieldRow(
                    'Target date',
                    primaryGoal.valueOrNull?.targetDate == null ? 'Not set' : DateFormat.yMMMd().format(primaryGoal.value!.targetDate!),
                  ),
                ],
                trailing: primaryGoal.valueOrNull != null
                    ? TextButton(onPressed: () => _editGoalTarget(context, ref, primaryGoal.value!), child: const Text('Edit'))
                    : null,
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Training preferences',
                rows: [
                  _fieldRow('Fitness level', _labelFor(kFitnessLevelOptions, p.fitnessLevel)),
                  _fieldRow('Location', _labelFor(kTrainingLocationOptions, p.trainingLocation)),
                  _fieldRow(
                    'Equipment',
                    equipment.isEmpty ? 'None' : equipment.map((e) => _labelFor(kEquipmentOptions, e)).join(', '),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Availability',
                rows: [
                  _fieldRow('Days per week', p.availabilityDaysPerWeek?.toString() ?? 'Not set'),
                  _fieldRow('Minutes per session', p.availabilityMinutesPerSession?.toString() ?? 'Not set'),
                  _fieldRow('Preferred time', _labelFor(kPreferredTimeOptions, p.preferredTimeOfDay)),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Nutrition preferences',
                rows: [
                  _fieldRow('Diet', _labelFor(kDietaryPreferenceOptions, p.dietaryPreference)),
                  _fieldRow(
                    'Restrictions',
                    restrictions.isEmpty ? 'None' : restrictions.map((r) => _labelFor(kDietaryRestrictionOptions, r)).join(', '),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              baseline.when(
                loading: () => const SizedBox.shrink(),
                error: (e, st) => const SizedBox.shrink(),
                data: (b) => b == null
                    ? const SizedBox.shrink()
                    : _SectionCard(
                        title: 'Fitness baseline',
                        rows: [
                          _fieldRow('Push-ups', b.pushUpsReps?.toString() ?? '—'),
                          _fieldRow('Squats', b.squatsReps?.toString() ?? '—'),
                          _fieldRow('Pull-ups', b.pullUpsReps?.toString() ?? '—'),
                          _fieldRow('Plank', b.plankSeconds == null ? '—' : '${b.plankSeconds}s'),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              Center(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/program'),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('View my program'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editGoalTarget(BuildContext context, WidgetRef ref, FitnessGoal goal) async {
    final weightController = TextEditingController(text: goal.targetValue?.toStringAsFixed(1) ?? '');
    DateTime? targetDate = goal.targetDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Edit goal target'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target weight (kg)'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: targetDate ?? now.add(const Duration(days: 90)),
                    firstDate: now.add(const Duration(days: 14)),
                    lastDate: now.add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => targetDate = picked);
                },
                icon: const Icon(Icons.event),
                label: Text(targetDate == null ? 'Pick a target date' : DateFormat.yMMMd().format(targetDate!)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    final weight = double.tryParse(weightController.text);
    if (result != true || weight == null || weight <= 0 || targetDate == null) return;

    await ref.read(profileRepositoryProvider).setGoalTarget(goal.userId, targetWeightKg: weight, targetDate: targetDate!);
    ref.invalidate(primaryGoalProvider);
    if (!context.mounted) return;

    final refresh = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Update your plan?'),
        content: const Text(
          'Your goal target changed. Regenerate your workout plan and nutrition targets to match, starting today?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Regenerate')),
        ],
      ),
    );
    if (refresh != true || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 16),
            Text('Updating your plan…'),
          ],
        ),
      ),
    );
    final regenResult = await regeneratePlanAndDiet(ref);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          regenResult == null
              ? 'Could not update your plan.'
              : regenResult.source == 'ai'
                  ? 'Plan and diet updated with AI from today onward.'
                  : 'Plan and diet updated from today onward (offline mode).',
        ),
      ),
    );
  }
}

(String, String) _fieldRow(String label, String value) => (label, value);

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows, this.trailing});
  final String title;
  final List<(String, String)> rows;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
