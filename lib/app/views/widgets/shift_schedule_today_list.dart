import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../data/models/scheduling/board_day.dart';
import '../../data/models/scheduling/board_employee.dart';
import '../../data/models/scheduling/shift_status.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_status_badges.dart';
import 'shift_schedule_utils.dart';

class ShiftScheduleTodayList extends GetView<ShiftScheduleController> {
  const ShiftScheduleTodayList({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = controller.todayEmployees;
      if (employees.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  controller.conflictFilterOnly.value
                      ? 'No employees with conflicts today.'
                      : 'No employees match the current filter.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: employees.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final employee = employees[index];
          final day = controller.todayDayFor(employee);
          if (day == null) return const SizedBox.shrink();
          return _TodayRow(
            employee: employee,
            day: day,
            accentColor: controller.colorForTemplate(day.templateId),
            onTap: () => controller.openCellDetail(employee, day),
          );
        },
      );
    });
  }
}

class _TodayRow extends StatelessWidget {
  const _TodayRow({
    required this.employee,
    required this.day,
    required this.onTap,
    this.accentColor,
  });

  final BoardEmployee employee;
  final BoardDay day;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final shiftLine = _shiftSubtitle(day);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(
                name: employee.fullName,
                color: accentColor ?? AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      employee.employeeCode,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (shiftLine.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        shiftLine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ShiftScheduleStatusBadges(day: day),
            ],
          ),
        ),
      ),
    );
  }

  String _shiftSubtitle(BoardDay day) {
    switch (day.status) {
      case ShiftStatus.assigned:
        final name = day.templateName ?? 'Shift';
        final start = formatTimeOfDay(day.shiftStart);
        final end = formatTimeOfDay(day.shiftEnd);
        if (start.isNotEmpty && end.isNotEmpty) {
          return '$name · $start – $end';
        }
        return name;
      case ShiftStatus.onLeave:
        return 'On leave today';
      case ShiftStatus.unassigned:
        return 'No shift assigned';
      case ShiftStatus.dayOff:
        return 'Scheduled off';
    }
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
