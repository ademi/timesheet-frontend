import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../themes/app_colors.dart';

/// FAB for shift schedule actions — hidden without `scheduling.manage`.
class ShiftScheduleFab extends GetView<ShiftScheduleController> {
  const ShiftScheduleFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.canManageSchedule.value) {
        return const SizedBox.shrink();
      }
      return FloatingActionButton(
        onPressed: controller.openFabMenu,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: AppColors.textLight),
      );
    });
  }
}
