import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/app_file_field.dart';
import '../../models/identity_card_attachment.dart';

/// Medicare / companion / disability / pension card upload row for Identity step.
class OnboardingIdentityCardField extends StatelessWidget {
  const OnboardingIdentityCardField({
    super.key,
    required this.label,
    required this.attachment,
    required this.enabled,
    required this.onPick,
    required this.onClearPending,
    this.numberController,
    this.numberLabel,
  });

  final String label;
  final IdentityCardAttachment attachment;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClearPending;
  final TextEditingController? numberController;
  final String? numberLabel;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pending = attachment.pending.value;
      final onFile =
          attachment.existingDocumentLabel.value ??
          (attachment.existingDocumentId.value != null
              ? 'Document on file'
              : null);
      final fileName = pending?.name ?? onFile;
      final hasFile = fileName != null && fileName.trim().isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (numberController != null) ...[
            TextField(
              controller: numberController,
              decoration: InputDecoration(
                labelText: numberLabel ?? 'Card number (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          AppFileField(
            label: label,
            fileName: fileName,
            enabled: enabled,
            onPick: onPick,
            onClear: pending != null && enabled ? onClearPending : null,
            pickLabel: hasFile ? 'Replace file' : 'Choose file',
          ),
          const SizedBox(height: 12),
        ],
      );
    });
  }
}
