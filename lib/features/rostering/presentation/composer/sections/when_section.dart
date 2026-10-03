import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/widgets/app_date_field.dart';
import '../../../../../shared/widgets/keyboard_time_field.dart';
import '../roster_composer_controller.dart';

class ComposerWhenSection extends GetView<RosterComposerController> {
  const ComposerWhenSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final start = controller.draft.value.scheduledStart ?? DateTime.now();
      final end =
          controller.draft.value.scheduledEnd ??
          start.add(const Duration(hours: 2));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('When', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Session start and end.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          AppDateField(
            label: 'Date',
            value: DateTime(start.year, start.month, start.day),
            onChanged: (d) {
              final nextStart = DateTime(
                d.year,
                d.month,
                d.day,
                start.hour,
                start.minute,
              );
              final nextEnd = DateTime(
                d.year,
                d.month,
                d.day,
                end.hour,
                end.minute,
              );
              controller.setSchedule(
                start: nextStart,
                end: nextEnd.isAfter(nextStart)
                    ? nextEnd
                    : nextStart.add(const Duration(hours: 1)),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KeyboardTimeField(
                  label: 'Start',
                  value: TimeOfDay(hour: start.hour, minute: start.minute),
                  onChanged: (t) {
                    controller.setSchedule(
                      start: DateTime(
                        start.year,
                        start.month,
                        start.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KeyboardTimeField(
                  label: 'End',
                  value: TimeOfDay(hour: end.hour, minute: end.minute),
                  onChanged: (t) {
                    controller.setSchedule(
                      end: DateTime(
                        end.year,
                        end.month,
                        end.day,
                        t.hour,
                        t.minute,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}
