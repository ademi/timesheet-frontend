import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import 'group_shift_remove_controller.dart';

class GroupShiftRemoveView extends GetView<GroupShiftRemoveController> {
  const GroupShiftRemoveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Remove from group')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          controller.participantName,
                          style: Get.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Group size ${controller.currentN} → ${controller.nextN}',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.openSlotBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            controller.rebalanceHint,
                            style: const TextStyle(color: AppColors.openSlot),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller.reasonCtrl,
                          enabled: !controller.isSaving.value,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Reason *',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FormStickyActions(
              onCancel:
                  controller.isSaving.value ? null : () => Get.back(),
              primaryLabel: 'Remove',
              onPrimary:
                  controller.isSaving.value ? null : controller.remove,
              isLoading: controller.isSaving.value,
            ),
          ],
        );
      }),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
