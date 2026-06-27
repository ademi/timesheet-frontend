import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../data/models/scheduling/board_day.dart';
import '../../data/models/scheduling/board_employee.dart';
import '../../data/models/scheduling/shift_source.dart';
import '../../data/models/scheduling/shift_status.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_conflict_messages.dart';
import 'shift_schedule_manage_dialogs.dart';

/// Bottom sheet for a single schedule cell — read-only detail or manage actions.
abstract final class ShiftScheduleCellSheet {
  ShiftScheduleCellSheet._();

  static Future<void> show({
    required BoardEmployee employee,
    required BoardDay day,
    required bool canManage,
    required ShiftScheduleController controller,
  }) {
    return showModalBottomSheet<void>(
      context: Get.context!,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ShiftScheduleCellSheetBody(
        employee: employee,
        day: day,
        canManage: canManage,
        controller: controller,
      ),
    );
  }
}

class _ShiftScheduleCellSheetBody extends StatelessWidget {
  const _ShiftScheduleCellSheetBody({
    required this.employee,
    required this.day,
    required this.canManage,
    required this.controller,
  });

  final BoardEmployee employee;
  final BoardDay day;
  final bool canManage;
  final ShiftScheduleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saving = controller.isSaving.value;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  employee.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${employee.employeeCode} · ${fmtSchedulingDateDisplay(day.date)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                _DetailRow(label: 'Status', value: _statusLabel(day.status)),
                if (day.source != null)
                  _DetailRow(label: 'Source', value: _sourceLabel(day.source!)),
                if (day.templateName != null && day.templateName!.isNotEmpty)
                  _DetailRow(label: 'Shift', value: day.templateName!),
                if (day.shiftStart != null && day.shiftEnd != null)
                  _DetailRow(
                    label: 'Hours',
                    value:
                        '${_formatTime(day.shiftStart!)} – ${_formatTime(day.shiftEnd!)}',
                  ),
                if (day.conflicts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Conflicts',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...day.conflicts.map(
                    (code) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        shiftScheduleConflictMessage(code),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                ],
                if (canManage) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Actions',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (saving)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _ActionTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Change shift',
                      onTap: () => controller.changeShiftOverride(
                        employee: employee,
                        day: day,
                      ),
                    ),
                    _ActionTile(
                      icon: Icons.event_busy_rounded,
                      label: 'Mark day off',
                      onTap: () => controller.markDayOff(
                        employee: employee,
                        day: day,
                      ),
                    ),
                    _ActionTile(
                      icon: Icons.beach_access_rounded,
                      label: 'Mark leave',
                      onTap: () => controller.markLeave(
                        employee: employee,
                        day: day,
                      ),
                    ),
                    if (day.source == ShiftSource.override)
                      _ActionTile(
                        icon: Icons.undo_rounded,
                        label: 'Clear override',
                        onTap: () => controller.clearOverride(
                          employee: employee,
                          day: day,
                        ),
                      ),
                    _ActionTile(
                      icon: Icons.repeat_rounded,
                      label: 'Recurring schedules',
                      onTap: () {
                        Navigator.pop(context);
                        controller.openRecurringSchedules(employee);
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  static String _formatTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  static String _statusLabel(ShiftStatus status) {
    switch (status) {
      case ShiftStatus.assigned:
        return 'Assigned';
      case ShiftStatus.onLeave:
        return 'On leave';
      case ShiftStatus.unassigned:
        return 'Unassigned';
      case ShiftStatus.dayOff:
        return 'Day off';
    }
  }

  static String _sourceLabel(ShiftSource source) {
    switch (source) {
      case ShiftSource.recurring:
        return 'Recurring';
      case ShiftSource.override:
        return 'Override';
      case ShiftSource.leave:
        return 'Leave';
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
