import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../data/models/scheduling/board_meta.dart';
import '../../data/models/scheduling/shift_status.dart';
import '../../themes/app_colors.dart';

class ShiftScheduleViewToggle extends GetView<ShiftScheduleController> {
  const ShiftScheduleViewToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isToday = controller.isTodayView.value;
      return SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: true,
            label: Text('Today'),
            icon: Icon(Icons.today_rounded, size: 18),
          ),
          ButtonSegment<bool>(
            value: false,
            label: Text('Week'),
            icon: Icon(Icons.calendar_view_week_rounded, size: 18),
          ),
        ],
        selected: {isToday},
        onSelectionChanged: (selection) {
          controller.toggleView(today: selection.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.textLight;
            }
            return AppColors.primary;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary;
            }
            return AppColors.cardBackground;
          }),
        ),
      );
    });
  }
}

class ShiftScheduleSummaryChips extends GetView<ShiftScheduleController> {
  const ShiftScheduleSummaryChips({super.key, this.meta});

  final BoardMeta? meta;

  @override
  Widget build(BuildContext context) {
    if (meta == null) return const SizedBox.shrink();

    return Obx(() {
      final active = controller.statusFilter.value;
      final conflictsOnly = controller.conflictFilterOnly.value;

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SummaryChip(
            label: 'Assigned ${meta!.assignedCount}',
            selected: active == ShiftStatus.assigned,
            onTap: () => controller.applyStatusFilter(
              active == ShiftStatus.assigned ? null : ShiftStatus.assigned,
            ),
          ),
          _SummaryChip(
            label: 'Unassigned ${meta!.unassignedCount}',
            selected: active == ShiftStatus.unassigned,
            onTap: () => controller.applyStatusFilter(
              active == ShiftStatus.unassigned ? null : ShiftStatus.unassigned,
            ),
          ),
          _SummaryChip(
            label: 'Leave ${meta!.onLeaveCount}',
            selected: active == ShiftStatus.onLeave,
            onTap: () => controller.applyStatusFilter(
              active == ShiftStatus.onLeave ? null : ShiftStatus.onLeave,
            ),
          ),
          _SummaryChip(
            label: 'Conflicts ${meta!.conflictCount}',
            selected: conflictsOnly,
            accentColor: AppColors.error,
            onTap: controller.toggleConflictFilter,
          ),
        ],
      );
    });
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.primary;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: selected ? AppColors.textLight : AppColors.textDark,
      ),
      selectedColor: color,
      backgroundColor: AppColors.cardBackground,
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
