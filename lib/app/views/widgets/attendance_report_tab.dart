import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_report_controller.dart';
import '../../themes/app_colors.dart';
import '../../utils/attendance_report_matrix.dart';

class AttendanceReportTab extends GetView<AttendanceReportController> {
  const AttendanceReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          _buildTopControls(context),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
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
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.reports.isEmpty) {
                    return Center(
                      child: Text(
                        'No data available.\nSelect dates and tap "Get Report".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  return _buildDataTable();
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDatePicker(context, true)),
              const SizedBox(width: 12),
              Expanded(child: _buildDatePicker(context, false)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => controller.fetchReport(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Get Report'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context, bool isStart) {
    return Obx(() {
      final date = isStart
          ? controller.startDate.value
          : controller.endDate.value;
      final label = isStart ? 'Start Date' : 'End Date';

      return InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textDark,
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            if (isStart) {
              controller.setStartDate(picked);
            } else {
              controller.setEndDate(picked);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date != null
                          ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                          : 'Select Date',
                      style: TextStyle(
                        fontSize: 13,
                        color: date != null
                            ? AppColors.textDark
                            : Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDataTable() {
    final matrix = AttendanceReportMatrix(controller.reports);
    final dates = matrix.dates;
    final employees = matrix.employees;
    final minWidth = 120.0 + (employees.length * 100.0) + 90.0;

    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: minWidth,
      headingRowColor:
          WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.1)),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.primaryDark,
        fontSize: 13,
      ),
      dataTextStyle: const TextStyle(
        color: AppColors.textDark,
        fontSize: 13,
      ),
      border: TableBorder(
        horizontalInside: BorderSide(color: AppColors.divider, width: 0.5),
        verticalInside: BorderSide(color: AppColors.divider, width: 0.5),
      ),
      columns: [
        const DataColumn2(
          label: Text('Date'),
          size: ColumnSize.M,
          fixedWidth: 110,
        ),
        ...employees.map(
          (employee) => DataColumn2(
            label: Text(
              employee,
              overflow: TextOverflow.ellipsis,
            ),
            size: ColumnSize.S,
            numeric: true,
          ),
        ),
        const DataColumn2(
          label: Text('Daily Total'),
          size: ColumnSize.S,
          numeric: true,
        ),
      ],
      rows: dates.map((date) {
        return DataRow(
          cells: [
            DataCell(Text(_formatMmDd(date))),
            ...employees.map((employee) {
              final hours = matrix.hoursFor(date, employee);
              return DataCell(
                Text(
                  hours.toStringAsFixed(1),
                  style: TextStyle(
                    color: hours == 0 ? Colors.grey.shade400 : AppColors.textDark,
                  ),
                ),
              );
            }),
            DataCell(
              Text(
                matrix.totalForDate(date).toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatMmDd(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        return '${parts[1]}-${parts[2]}';
      }
    } catch (_) {}
    return dateStr;
  }
}
