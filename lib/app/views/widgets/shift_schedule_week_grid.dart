import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/shift_schedule_controller.dart';
import '../../data/models/scheduling/board_employee.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_cell.dart';
import 'shift_schedule_utils.dart';

class ShiftScheduleWeekGrid extends GetView<ShiftScheduleController> {
  const ShiftScheduleWeekGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = controller.weekEmployees;
      final dates = controller.weekDates;

      if (employees.isEmpty) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  controller.conflictFilterOnly.value
                      ? 'No employees with conflicts this week.'
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

      if (dates.isEmpty) {
        return const Center(child: Text('No dates in schedule range.'));
      }

      final minWidth =
          148.0 + dates.length * ShiftScheduleCell.minWidth + 24.0;

      return LayoutBuilder(
        builder: (context, constraints) {
          // Sticky employee column only when the grid overflows horizontally.
          // With fixedLeftColumns on a wide viewport, DataTable2 leaves a gap
          // between the fixed and scrollable sections (web/desktop only).
          final stickyEmployeeColumn = constraints.maxWidth < minWidth;
          final expandDayColumns = !stickyEmployeeColumn;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: constraints.maxHeight,
                child: DataTable2(
                    columnSpacing: 8,
                    horizontalMargin: 12,
                    minWidth: expandDayColumns ? constraints.maxWidth : minWidth,
                    fixedLeftColumns: stickyEmployeeColumn ? 1 : 0,
                    headingRowHeight: 44,
                    dataRowHeight: ShiftScheduleCell.minHeight + 12,
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.primary.withValues(alpha: 0.08),
                    ),
                    columns: [
                      const DataColumn2(
                        label: Text(
                          'Employee',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        size: ColumnSize.L,
                        fixedWidth: 140,
                      ),
                      ...dates.map(
                        (date) => _dayColumn(
                          date,
                          expandToFill: expandDayColumns,
                        ),
                      ),
                    ],
                    rows: employees
                        .map(
                          (employee) => _employeeRow(
                            employee,
                            dates,
                            expandCells: expandDayColumns,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
          );
        },
      );
    });
  }

  DataColumn2 _dayColumn(DateTime date, {required bool expandToFill}) {
    final isToday = controller.isTodayDate(date);
    final label = formatSchedulingShortDate(date);
    return DataColumn2(
      label: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: isToday
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
            color: isToday ? AppColors.primaryDark : AppColors.textDark,
          ),
        ),
      ),
      size: ColumnSize.S,
      minWidth: ShiftScheduleCell.minWidth,
      fixedWidth: expandToFill ? null : ShiftScheduleCell.minWidth,
    );
  }

  DataRow _employeeRow(
    BoardEmployee employee,
    List<DateTime> dates, {
    required bool expandCells,
  }) {
    return DataRow(
      cells: [
        DataCell(_EmployeeNameCell(employee: employee)),
        ...dates.map((date) {
          final day = controller.dayForEmployee(employee, date);
          if (day == null) {
            return DataCell(
              SizedBox(
                width: expandCells ? double.infinity : null,
                height: ShiftScheduleCell.minHeight,
              ),
            );
          }
          return DataCell(
            ShiftScheduleCell(
              day: day,
              templateColor: controller.colorForTemplate(day.templateId),
              isTodayColumn: controller.isTodayDate(date),
              expandWidth: expandCells,
              onTap: () => controller.openCellDetail(employee, day),
            ),
          );
        }),
      ],
    );
  }
}

class _EmployeeNameCell extends StatelessWidget {
  const _EmployeeNameCell({required this.employee});

  final BoardEmployee employee;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            employee.fullName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            employee.employeeCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
