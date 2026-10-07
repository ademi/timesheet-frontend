import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/credential_models.dart';
import '../utils/credential_category_groups.dart';

/// Vertical, sectioned multi-select for credential / required-document types.
class CredentialCategoryGroupedPicker extends StatelessWidget {
  const CredentialCategoryGroupedPicker({
    super.key,
    required this.choices,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });

  final List<CredentialCategory> choices;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final groups = groupCredentialCategories(choices);
    if (groups.isEmpty) {
      return const Text(
        'No document types available.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          Text(
            groups[i].title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          for (final cat in groups[i].items)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(credentialTypeLabel(cat.code)),
              value: selected.contains(cat.code),
              onChanged:
                  enabled ? (_) => onToggle(cat.code) : null,
            ),
        ],
      ],
    );
  }
}
