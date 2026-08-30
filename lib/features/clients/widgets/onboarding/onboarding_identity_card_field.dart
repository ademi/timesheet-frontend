import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      final onFile = attachment.existingDocumentLabel.value ??
          (attachment.existingDocumentId.value != null
              ? 'Document on file'
              : null);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          if (numberController != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: numberController,
              decoration: InputDecoration(
                labelText: numberLabel ?? 'Card number (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(pending != null || onFile != null ? 'Replace file' : 'Attach file'),
          ),
          if (onFile != null && pending == null) ...[
            const SizedBox(height: 6),
            Text(
              onFile,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (pending != null) ...[
            const SizedBox(height: 6),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              title: Text(pending.name, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: enabled ? onClearPending : null,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      );
    });
  }
}
