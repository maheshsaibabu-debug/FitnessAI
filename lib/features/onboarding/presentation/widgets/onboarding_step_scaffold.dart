import 'package:flutter/material.dart';

/// Consistent chrome for one page of the onboarding wizard: title,
/// optional subtitle, scrollable body. Next/back controls live in the
/// hosting [OnboardingFlowScreen], not here, so every step's body can
/// stay focused on just its own fields.
class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

/// A single-select row of chips over a fixed (value, label) option list.
class ChoiceChipGroup extends StatelessWidget {
  const ChoiceChipGroup({super.key, required this.options, required this.selected, required this.onSelected});

  final List<(String value, String label)> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

/// A multi-select row of chips over a fixed (value, label) option list.
class MultiChoiceChipGroup extends StatelessWidget {
  const MultiChoiceChipGroup({super.key, required this.options, required this.selectedValues, required this.onToggle});

  final List<(String value, String label)> options;
  final Set<String> selectedValues;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          FilterChip(
            label: Text(label),
            selected: selectedValues.contains(value),
            onSelected: (_) => onToggle(value),
          ),
      ],
    );
  }
}
