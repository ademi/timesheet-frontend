import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';

/// Placeholder — form override chips land in Task 4.
class ComposerFormsSection extends StatelessWidget {
  const ComposerFormsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forms', style: Get.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Form requirements will appear here.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
