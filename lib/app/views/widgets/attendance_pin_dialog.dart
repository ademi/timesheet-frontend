import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';
import '../../utils/employee_clock_status.dart';
import '../../themes/app_colors.dart';
import 'pin_input_field.dart';

class AttendancePinDialog extends StatelessWidget {
  const AttendancePinDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AttendanceController>();

    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          final emp = c.dialogEmployee.value;
          final action = c.dialogAction.value;
          if (emp == null || action == null) {
            return const SizedBox.shrink();
          }
          final title =
              action == AttendanceDialogAction.clockIn
                  ? 'Confirm clock in'
                  : 'Confirm clock out';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  emp.fullName.isNotEmpty ? emp.fullName : 'Employee',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                if (employeeContactSubtitle(emp).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    employeeContactSubtitle(emp),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Enter your 4-digit PIN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                PinInputField(
                  controller: c.pinConfirmController,
                  autofocus: true,
                  enabled: !c.isVerifying.value && !c.dialogSubmitting.value,
                  onCompleted: (_) {
                    if (!c.isVerifying.value && !c.dialogSubmitting.value) {
                      c.submitAttendanceDialog();
                    }
                  },
                ),
                Obx(() {
                  if (c.dialogError.value.isEmpty) {
                    return const SizedBox(height: 12);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        c.dialogError.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Obx(() {
                  final busy = c.isVerifying.value || c.dialogSubmitting.value;
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: busy ? null : c.cancelAttendanceDialog,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              busy ? null : () => c.submitAttendanceDialog(),
                          child:
                              busy
                                  ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Submit'),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          );
        }),
      ),
    );
  }
}
