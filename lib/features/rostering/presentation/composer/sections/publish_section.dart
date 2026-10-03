import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../roster_composer_controller.dart';

class ComposerPublishSection extends GetView<RosterComposerController> {
  const ComposerPublishSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.draft.value.status;
      final showMenu = controller.showPublishMenu.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Publish', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Assign & publish, or open slots for claim.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:
                    status == 'draft'
                        ? AppColors.draftChipBackground
                        : AppColors.successBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status == 'draft' ? 'Draft' : status,
                style: TextStyle(
                  color:
                      status == 'draft'
                          ? AppColors.draftChip
                          : AppColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (showMenu) ...[
            const SizedBox(height: 12),
            ListTile(
              key: const Key('composer-publish-assign'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Assign & publish'),
              subtitle: const Text('Publish with selected workers'),
              onTap:
                  () => controller.publish(
                    ComposerPublishMode.assignAndPublish,
                  ),
            ),
            ListTile(
              key: const Key('composer-publish-claim'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Open for claim'),
              subtitle: const Text('Publish with open slots'),
              onTap:
                  () => controller.publish(ComposerPublishMode.openForClaim),
            ),
          ],
        ],
      );
    });
  }
}
