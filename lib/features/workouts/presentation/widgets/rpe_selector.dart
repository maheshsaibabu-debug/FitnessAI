import 'package:flutter/material.dart';

/// Rate of Perceived Exertion, 1-10. Optional everywhere it's used
/// (product spec §20) — [value] can be null, and tapping the already-
/// selected value clears it rather than forcing a re-pick.
class RpeSelector extends StatelessWidget {
  const RpeSelector({super.key, required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 1; i <= 10; i++)
          ChoiceChip(
            label: Text('$i'),
            selected: value == i,
            onSelected: (_) => onChanged(value == i ? null : i),
          ),
      ],
    );
  }
}
