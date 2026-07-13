import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_no_access.dart';
import 'shift_schedule_summary_chips.dart';
import 'shift_schedule_today_list.dart';
import 'shift_schedule_top_controls.dart';
import 'shift_schedule_week_grid.dart';

class ShiftScheduleBody extends GetView<ShiftScheduleController> {
  const ShiftScheduleBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isAccessDenied.value) {
        return const ShiftScheduleNoAccess();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ShiftScheduleTopControls(),
          const SizedBox(height: 12),
          Obx(
            () => ShiftScheduleSummaryChips(
              meta: controller.board.value?.meta,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _ScheduleContentCard()),
        ],
      );
    });
  }
}

class _ScheduleContentCard extends GetView<ShiftScheduleController> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Obx(() {
          if (controller.isLoading.value && controller.board.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final board = controller.board.value;
          if (board == null) {
            return _emptyScrollable('No schedule data.\nPull down to refresh.');
          }

          if (board.employees.isEmpty) {
            return _emptyScrollable(
              'No employees on the schedule for this period.',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.refreshBoard,
            child: controller.isTodayView.value
                ? const ShiftScheduleTodayList()
                : const ShiftScheduleWeekGrid(),
          );
        }),
      ),
    );
  }

  Widget _emptyScrollable(String message) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: controller.refreshBoard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 160,
            child: Center(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
