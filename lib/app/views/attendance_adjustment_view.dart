import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/attendance_adjustment_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import 'widgets/app_back_button.dart';

class AttendanceAdjustmentView
    extends GetView<AttendanceAdjustmentController> {
  const AttendanceAdjustmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRoute: AppRoutes.adminAttendanceCorrections,
        ),
        title: Text(controller.title),
        backgroundColor: AppColors.darkBrown,
      ),
      body: MaxWidthBox(
        maxWidth: Breakpoints.formMaxWidth,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          _employeeHeader(),
          const SizedBox(height: 16),
          if (controller.needsClockIn) ...[
            _TimeField(
              label: 'Clock-In',
              value: controller.clockInAt,
              onPick: (dt) => controller.setClockIn(dt),
            ),
            const SizedBox(height: 12),
          ] else
            _readOnlyClockIn(),
          _TimeField(
            label: 'Clock-Out',
            value: controller.clockOutAt,
            onPick: (dt) => controller.setClockOut(dt),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason (required)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            if (controller.errorText.value.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                controller.errorText.value,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            );
          }),
          const SizedBox(height: 12),
          Obx(
            () => SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: controller.isSubmitting.value
                    ? null
                    : controller.submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: controller.isSubmitting.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.textLight,
                        ),
                      )
                    : const Text(
                        'Submit Correction',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _employeeHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              controller.args.employeeName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBrown,
              ),
            ),
          ),
          if (controller.args.exceptionType != null)
            Text(
              controller.args.exceptionType!.replaceAll('_', ' '),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  Widget _readOnlyClockIn() {
    final clockIn = controller.args.initialClockInAt?.toLocal();
    if (clockIn == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Clock-In (existing)',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(clockIn.toString().substring(0, 16)),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final Rxn<DateTime> value;
  final ValueChanged<DateTime> onPick;

  Future<void> _pick(BuildContext context) async {
    final initial = value.value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;
    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return;
    onPick(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = value.value;
      return InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.access_time_rounded),
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            current != null
                ? current.toString().substring(0, 16)
                : 'Select date & time',
            style: TextStyle(
              color: current != null ? AppColors.textDark : Colors.grey,
            ),
          ),
        ),
      );
    });
  }
}
