import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';
import '../../core/constants/australian_states.dart';

/// Required Australian state/territory selector.
class AuStateDropdown extends StatelessWidget {
  const AuStateDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'State',
    this.profileStyle = false,
    this.decoration,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool profileStyle;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeAustralianState(value);
    final items = australianStateItems(value);

    return DropdownButtonFormField<String>(
      value: items.contains(normalized) ? normalized : items.first,
      items: [
        for (final state in items)
          DropdownMenuItem(value: state, child: Text(state)),
      ],
      onChanged: (selected) {
        if (selected == null) return;
        onChanged(selected);
      },
      decoration: decoration ?? _decoration(label, profileStyle: profileStyle),
    );
  }
}

/// Optional Australian state/territory selector (empty = not set).
class OptionalAuStateDropdown extends StatelessWidget {
  const OptionalAuStateDropdown({
    super.key,
    required this.controller,
    this.label = 'State',
    this.profileStyle = true,
    this.decoration,
  });

  final TextEditingController controller;
  final String label;
  final bool profileStyle;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim();
    final items = australianStateItems(current.isEmpty ? null : current);

    return DropdownButtonFormField<String?>(
      value: current.isEmpty
          ? null
          : (items.contains(current) ? current : null),
      decoration: decoration ?? _decoration(label, profileStyle: profileStyle),
      hint: const Text('Select state'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('—')),
        for (final state in items)
          DropdownMenuItem(value: state, child: Text(state)),
      ],
      onChanged: (selected) {
        controller.text = selected ?? '';
      },
    );
  }
}

InputDecoration _decoration(String label, {required bool profileStyle}) {
  if (!profileStyle) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    );
  }

  return InputDecoration(
    labelText: label,
    prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primaryDark),
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
  );
}
