import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../roster_composer_controller.dart';

/// Stage A support anchor — full NDIS picker polish can deepen in Task 4.
class ComposerSupportSection extends GetView<RosterComposerController> {
  const ComposerSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final code = controller.draft.value.supportItemCode ?? '';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Support', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Anchor item for publish.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('support-$code'),
            initialValue: code,
            decoration: const InputDecoration(
              labelText: 'Support item code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => controller.setSupportItemCode(v.trim()),
          ),
        ],
      );
    });
  }
}