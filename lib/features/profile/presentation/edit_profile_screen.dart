import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../onboarding/presentation/onboarding_options.dart';
import '../../onboarding/presentation/widgets/onboarding_step_scaffold.dart';

Set<String> _parseJsonList(String json) {
  if (json.isEmpty) return {};
  return (jsonDecode(json) as List).map((v) => v.toString()).toSet();
}

/// A single scrollable edit form covering every field collected across
/// onboarding steps 1, 3, 4 and 5 — unlike onboarding itself, this isn't a
/// wizard, since the user is changing already-known values, not building
/// them up for the first time. Goal type/target and baseline are edited
/// separately (see ProfileScreen), since they live on different tables.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  String? _sex;
  DateTime? _dateOfBirth;
  String? _fitnessLevel;
  String? _trainingLocation;
  Set<String> _equipment = {};
  int _daysPerWeek = 3;
  int _minutesPerSession = 30;
  String? _preferredTime;
  String? _dietaryPreference;
  Set<String> _dietaryRestrictions = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(profileRepositoryProvider).activeProfileOnce();
    if (profile == null || !mounted) return;
    setState(() {
      _profile = profile;
      _nameController.text = profile.name;
      _heightController.text = profile.heightCm?.toStringAsFixed(0) ?? '';
      _sex = profile.sex;
      _dateOfBirth = profile.dateOfBirth;
      _fitnessLevel = profile.fitnessLevel;
      _trainingLocation = profile.trainingLocation;
      _equipment = _parseJsonList(profile.equipmentJson);
      _daysPerWeek = profile.availabilityDaysPerWeek ?? 3;
      _minutesPerSession = profile.availabilityMinutesPerSession ?? 30;
      _preferredTime = profile.preferredTimeOfDay;
      _dietaryPreference = profile.dietaryPreference;
      _dietaryRestrictions = _parseJsonList(profile.dietaryRestrictionsJson);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null || _nameController.text.trim().isEmpty || _sex == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            profile.id,
            name: _nameController.text,
            sex: _sex!,
            dateOfBirth: _dateOfBirth,
            heightCm: double.tryParse(_heightController.text),
            trainingLocation: _trainingLocation,
            equipment: _equipment,
            fitnessLevel: _fitnessLevel,
            availabilityDaysPerWeek: _daysPerWeek,
            availabilityMinutesPerSession: _minutesPerSession,
            preferredTimeOfDay: _preferredTime,
            dietaryPreference: _dietaryPreference,
            dietaryRestrictions: _dietaryRestrictions,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Edit profile')), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 20),
            Text('Sex', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ChoiceChipGroup(options: kSexOptions, selected: _sex, onSelected: (v) => setState(() => _sex = v)),
            const SizedBox(height: 20),
            Text('Date of birth', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(now.year - 30),
                  firstDate: DateTime(now.year - 100),
                  lastDate: DateTime(now.year - 13),
                );
                if (picked != null) setState(() => _dateOfBirth = picked);
              },
              child: Text(_dateOfBirth == null
                  ? 'Select date of birth'
                  : '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Height (cm)'),
            ),
            const SizedBox(height: 8),
            Text(
              'Weight is logged separately (see Track) — every entry is kept as history, so it isn\'t edited here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            Text('Training preferences', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text('Fitness level', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ChoiceChipGroup(
              options: kFitnessLevelOptions,
              selected: _fitnessLevel,
              onSelected: (v) => setState(() => _fitnessLevel = v),
            ),
            const SizedBox(height: 20),
            Text('Where do you train?', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ChoiceChipGroup(
              options: kTrainingLocationOptions,
              selected: _trainingLocation,
              onSelected: (v) => setState(() => _trainingLocation = v),
            ),
            const SizedBox(height: 20),
            Text('Equipment', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            MultiChoiceChipGroup(
              options: kEquipmentOptions,
              selectedValues: _equipment,
              onToggle: (v) => setState(() {
                _equipment.contains(v) ? _equipment.remove(v) : _equipment.add(v);
              }),
            ),
            const SizedBox(height: 28),
            Text('Availability', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text('$_daysPerWeek day${_daysPerWeek == 1 ? '' : 's'} per week', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: _daysPerWeek.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$_daysPerWeek',
              onChanged: (v) => setState(() => _daysPerWeek = v.round()),
            ),
            const SizedBox(height: 12),
            Text('$_minutesPerSession minutes per session', style: Theme.of(context).textTheme.labelLarge),
            Slider(
              value: _minutesPerSession.toDouble(),
              min: 10,
              max: 90,
              divisions: 16,
              label: '$_minutesPerSession',
              onChanged: (v) => setState(() => _minutesPerSession = v.round()),
            ),
            const SizedBox(height: 20),
            Text('Preferred time of day', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ChoiceChipGroup(
              options: kPreferredTimeOptions,
              selected: _preferredTime,
              onSelected: (v) => setState(() => _preferredTime = v),
            ),
            const SizedBox(height: 28),
            Text('Nutrition preferences', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text('Diet', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ChoiceChipGroup(
              options: kDietaryPreferenceOptions,
              selected: _dietaryPreference,
              onSelected: (v) => setState(() => _dietaryPreference = v),
            ),
            const SizedBox(height: 20),
            Text('Restrictions (optional)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            MultiChoiceChipGroup(
              options: kDietaryRestrictionOptions,
              selectedValues: _dietaryRestrictions,
              onToggle: (v) => setState(() {
                _dietaryRestrictions.contains(v) ? _dietaryRestrictions.remove(v) : _dietaryRestrictions.add(v);
              }),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
