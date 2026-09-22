import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import 'exercise_animation_view.dart';

/// The exercise-info card shown at the top of a set: a numbered badge,
/// the illustration, a target-muscle chip, a sets/reps/rest stat row,
/// and a form tip + common-mistake note pulled from the exercise's own
/// bundled data (assets/data/exercises.json) — nothing invented, just
/// finally surfaced. Modeled on the "one card per exercise" layout
/// common across fitness apps (numbered header, stat icons, form/note
/// callouts), with our vector illustration standing in for a photo.
class ExerciseDetailCard extends StatelessWidget {
  const ExerciseDetailCard({
    super.key,
    required this.index,
    required this.exercise,
    required this.sex,
    required this.targetSets,
    this.targetReps,
    this.targetDurationSeconds,
    required this.restSeconds,
  });

  final int index;
  final Exercise exercise;
  final StickFigureSex sex;
  final int targetSets;
  final int? targetReps;
  final int? targetDurationSeconds;
  final int restSeconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muscles = _decodeList(exercise.primaryMusclesJson);
    final formCues = _decodeList(exercise.formCuesJson);
    final commonMistakes = _decodeList(exercise.commonMistakesJson);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NumberBadge(index: index),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      if (muscles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Target: ${muscles.map(_titleCase).join(', ')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ExerciseAnimationView(exerciseId: exercise.id, sex: sex),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatChip(icon: Icons.repeat, label: '$targetSets sets'),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.fitness_center,
                      label: targetReps != null ? '$targetReps reps' : '${targetDurationSeconds ?? 0}s',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(icon: Icons.timer_outlined, label: '${restSeconds}s rest'),
                  ],
                ),
                if (formCues.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _CalloutRow(icon: Icons.check_circle_outline, color: scheme.primary, text: formCues.first),
                ],
                if (commonMistakes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _CalloutRow(icon: Icons.error_outline, color: scheme.error, text: commonMistakes.first),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _decodeList(String json) {
    if (json.isEmpty) return const [];
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return decoded.map((e) => e.toString()).toList();
  }

  String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
      child: Text(
        index.toString().padLeft(2, '0'),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CalloutRow extends StatelessWidget {
  const _CalloutRow({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      ],
    );
  }
}
