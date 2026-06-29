import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/attendance_corrections_controller.dart';
import '../data/models/attendance/attendance_exception_model.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class AttendanceCorrectionsView
    extends GetView<AttendanceCorrectionsController> {
  const AttendanceCorrectionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: const Text('Attendance Corrections'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.loadExceptions,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.createManualEntry,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Manual Entry'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            _buildFilters(context),
            const SizedBox(height: 12),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.exceptions.isEmpty) {
                  return Center(
                    child: Text(
                      'No exceptions for the selected dates.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: controller.exceptions.length,
                  itemBuilder: (_, i) {
                    final item = controller.exceptions[i];
                    return _ExceptionCard(
                      exception: item,
                      employeeName:
                          controller.employeeName(item.employeeId),
                      onCorrect: () => controller.openCorrection(item),
                      onHistory: () => controller.showHistory(item),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _dateField(context, isFrom: true)),
          const SizedBox(width: 10),
          Expanded(child: _dateField(context, isFrom: false)),
          const SizedBox(width: 10),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: controller.loadExceptions,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(Icons.search_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(BuildContext context, {required bool isFrom}) {
    return Obx(() {
      final date = isFrom ? controller.fromDate.value : controller.toDate.value;
      return InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            if (isFrom) {
              controller.setFromDate(picked);
            } else {
              controller.setToDate(picked);
            }
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: isFrom ? 'From' : 'To',
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    });
  }
}

class _ExceptionCard extends StatelessWidget {
  const _ExceptionCard({
    required this.exception,
    required this.employeeName,
    required this.onCorrect,
    required this.onHistory,
  });

  final AttendanceExceptionModel exception;
  final String employeeName;
  final VoidCallback onCorrect;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    employeeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBrown,
                    ),
                  ),
                ),
                _ExceptionBadge(type: exception.exceptionType),
              ],
            ),
            const SizedBox(height: 8),
            _timeRow('In', exception.clockInAt, exception.clockInSource),
            const SizedBox(height: 2),
            _timeRow('Out', exception.clockOutAt, exception.clockOutSource),
            if (exception.anomalyFlag) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.orange.shade800),
                  const SizedBox(width: 4),
                  Text(
                    'Anomaly flagged — please review',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('History'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onCorrect,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Correct'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRow(String label, DateTime? time, String? source) {
    final text = time != null
        ? time.toLocal().toString().substring(0, 16)
        : '—';
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Text(text, style: const TextStyle(fontSize: 13)),
        if (source == 'admin_adjustment') ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'manual',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ExceptionBadge extends StatelessWidget {
  const _ExceptionBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _styleFor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  (String, Color) _styleFor(String type) {
    switch (type) {
      case 'missing_clock_out':
        return ('Missing clock-out', Colors.redAccent);
      case 'manual_adjustment':
        return ('Manual adjustment', AppColors.primaryDark);
      case 'long_shift':
        return ('Long shift', Colors.deepOrange);
      default:
        return ('Needs review', Colors.brown);
    }
  }
}
