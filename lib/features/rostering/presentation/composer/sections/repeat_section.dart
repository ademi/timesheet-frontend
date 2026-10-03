import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../roster_composer_controller.dart';

/// Stage A toggle shell — A7 template fields land in Task 5.
class ComposerRepeatSection extends GetView<RosterComposerController> {
  const ComposerRepeatSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.draft.value.repeatEnabled;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Repeat', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Turn on to write a recurrence template.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeat this support'),
            value: enabled,
            onChanged: controller.setRepeatEnabled,
          ),
          if (enabled)
            const Text(
              'Frequency and horizon controls arrive in Task 5.',
              style: TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
        ],
      );
    });
  }
}
