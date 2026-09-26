import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import 'group_shift_attendance_controller.dart';

class GroupShiftAttendanceView extends GetView<GroupShiftAttendanceController> {
  const GroupShiftAttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final att = controller.attendance.value;
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
                          controller.exportNHint,
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
                            controller.oneClockHint,
                            style: const TextStyle(color: AppColors.openSlot),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Billing attendance', style: Get.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ...[
                          ('present', 'Present — full share'),
                          ('no_show', 'No-show — stay on roster, drop from N'),
                          ('partial', 'Partial — bill attended minutes'),
                        ].map(
                          (opt) => RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            title: Text(opt.$2),
                            value: opt.$1,
                            groupValue: att,
                            onChanged:
                                controller.isSaving.value
                                    ? null
                                    : (v) {
                                      if (v != null) controller.setAttendance(v);
                                    },
                          ),
                        ),
                        if (controller.showAttendedMinutes) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: controller.attendedMinutesCtrl,
                            enabled: !controller.isSaving.value,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Attended minutes *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
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
              primaryLabel: 'Save',
              onPrimary:
                  controller.isSaving.value ? null : controller.save,
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
