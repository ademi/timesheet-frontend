import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../roster_composer_controller.dart';

/// Publish status + open-slot warning (action lives in the footer).
class ComposerPublishSection extends GetView<RosterComposerController> {
  const ComposerPublishSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = controller.draft.value.status;
      final open = controller.unassignedSlotCount;
      final assigned = controller.assignedWorkerCount;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Publish', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            assigned == 0
                ? 'Publish opens all worker slots for claim.'
                : open == 0
                ? 'Publish assigns the selected workers.'
                : 'Publish assigns selected workers; empty slots stay open for claim.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
          if (open > 0) ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('composer-publish-open-slots-warning'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.openSlotBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.openSlot),
              ),
              child: Text(
                open == 1
                    ? '1 worker slot is unassigned. Once published, contractors can claim it.'
                    : '$open worker slots are unassigned. Once published, contractors can claim them.',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}
