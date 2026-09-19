import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "colored circle behind an icon" mark used for goals, plan items,
/// and achievements — one consistent visual unit instead of every screen
/// picking its own icon treatment.
class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({super.key, required this.icon, required this.categoryKey, this.size = 44});

  final IconData icon;

  /// Any stable string — the badge's color is derived from it, so the
  /// same key always renders the same color across screens.
  final String categoryKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.categoryColorFor(categoryKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.background, shape: BoxShape.circle),
      child: Icon(icon, color: color.foreground, size: size * 0.5),
    );
  }
}

/// A full-width selectable row: icon badge + label + trailing check —
/// the layout used for the onboarding goals/preferences screens in the
/// reference design, replacing plain wrap-chips for single/multi choice
/// lists where each option benefits from an icon.
class SelectableIconRow extends StatelessWidget {
  const SelectableIconRow({
    super.key,
    required this.icon,
    required this.categoryKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String categoryKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CategoryIconBadge(icon: icon, categoryKey: categoryKey, size: 40),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.check_circle, color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
