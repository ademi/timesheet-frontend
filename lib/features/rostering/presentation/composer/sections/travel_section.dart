import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';

/// Placeholder — travel shares land in Task 4.
class ComposerTravelSection extends StatelessWidget {
  const ComposerTravelSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Travel', style: Get.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Optional. Empty is OK.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );
  }
}
