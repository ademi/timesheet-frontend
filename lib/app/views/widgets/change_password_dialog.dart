import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/attendance_controller.dart';
import '../../themes/app_colors.dart';

class ChangePasswordDialog extends StatelessWidget {
  const ChangePasswordDialog({super.key});

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
          if (emp == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBrown,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You are using the default password.\nPlease set a new one to continue.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: c.newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c.confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Obx(() {
                  if (c.changePasswordError.value.isEmpty) {
                    return const SizedBox(height: 12);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      c.changePasswordError.value,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Obx(() {
                  final busy =
                      c.isChangingPassword.value || c.dialogSubmitting.value;
                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              busy
                                  ? null
                                  : () {
                                    c.changePasswordError.value = '';
                                    c.newPasswordController.clear();
                                    c.confirmPasswordController.clear();
                                    Get.back(result: false);
                                  },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              busy ? null : () => c.submitChangePassword(),
                          child:
                              busy
                                  ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Change & Clock In'),
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
