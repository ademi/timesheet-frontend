import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../credentials/data/models/credential_models.dart';

/// Chip picker + save for engagement required document categories.
class RequiredDocCategoriesEditor extends StatelessWidget {
  const RequiredDocCategoriesEditor({
    super.key,
    required this.choices,
    required this.selected,
    required this.canEdit,
    required this.isEnded,
    required this.onToggle,
    required this.onSave,
    this.isSaving = false,
    this.isLoadingChoices = false,
  });

  static const helperText =
      'Choose which certificates this worker must submit. Saving updates '
      'the requirements for this engagement. It does not accept or reject files.';

  final List<CredentialCategory> choices;
  final Set<String> selected;
  final bool canEdit;
  final bool isEnded;
  final ValueChanged<String> onToggle;
  final VoidCallback onSave;
  final bool isSaving;
  final bool isLoadingChoices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          helperText,
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (canEdit && !isEnded) ...[
          if (isLoadingChoices && choices.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in choices)
                  FilterChip(
                    label: Text(cat.label),
                    selected: selected.contains(cat.code),
                    onSelected:
                        isSaving ? null : (_) => onToggle(cat.code),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isSaving ? null : onSave,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child:
                  isSaving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Save certificates'),
            ),
          ),
        ] else
          Text(
            _readOnlyLabels(selected),
            style: const TextStyle(color: AppColors.textMuted),
          ),
      ],
    );
  }

  String _readOnlyLabels(Set<String> codes) {
    if (codes.isEmpty) return 'None required';
    final labels =
        codes
            .map((code) {
              for (final choice in choices) {
                if (choice.code == code) return choice.label;
              }
              return credentialTypeLabel(code);
            })
            .toList();
    return labels.join(', ');
  }
}
