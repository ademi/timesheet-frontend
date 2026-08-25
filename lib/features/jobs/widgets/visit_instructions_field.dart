import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';

/// Free-text visit instructions — one non-empty line becomes one task title.
class VisitInstructionsField extends StatelessWidget {
  const VisitInstructionsField({
    super.key,
    required this.controller,
    this.labelText = 'Further instructions (optional)',
    this.helperText =
        'One task per line. Copied onto visits for workers to follow.',
    this.maxLines = 4,
  });

  final TextEditingController controller;
  final String labelText;
  final String? helperText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Instructions for workers',
          style: Get.textTheme.titleSmall,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('visit-instructions-field'),
          controller: controller,
          maxLines: maxLines,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: labelText,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
