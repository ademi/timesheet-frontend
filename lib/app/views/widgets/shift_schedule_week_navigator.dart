import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_utils.dart';

class ShiftScheduleWeekNavigator extends GetView<ShiftScheduleController> {
  const ShiftScheduleWeekNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final label = formatWeekRangeLabel(controller.weekStart.value);
      return Row(
        children: [
          IconButton(
            tooltip: 'Previous week',
            onPressed: controller.goToPreviousWeek,
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.primary,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next week',
            onPressed: controller.goToNextWeek,
            icon: const Icon(Icons.chevron_right_rounded),
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: controller.goToToday,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Today'),
          ),
        ],
      );
    });
  }
}
