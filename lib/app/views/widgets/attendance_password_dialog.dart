import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';

class AttendancePasswordDialog extends StatelessWidget {
  const AttendancePasswordDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AttendanceController>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Obx(() {
          final emp = c.dialogEmployee.value;
          final action = c.dialogAction.value;
          if (emp == null || action == null) {
            return const SizedBox.shrink();
          }
          final title = action == AttendanceDialogAction.clockIn
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
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Employee',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                InputDecorator(
                  decoration: InputDecoration(
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    emp.email,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: c.passwordConfirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Obx(() {
                  if (c.dialogError.value.isEmpty) {
                    return const SizedBox(height: 12);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      c.dialogError.value,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 13,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                Obx(
                  () {
                    final busy =
                        c.isVerifying.value || c.dialogSubmitting.value;
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
                            child: busy
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
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
