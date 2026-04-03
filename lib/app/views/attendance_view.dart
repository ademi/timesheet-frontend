import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../themes/app_colors.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBrown,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yemen Gate',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Attendance',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => authController.logout(),
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            label: const Text(
              'Logout',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.employeesLoading.value) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          if (controller.allEmployees.isEmpty) {
            return const Center(
              child: Text(
                'No employees yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            );
          }

          final count = controller.visibleCount.value;
          return ListView.builder(
            controller: controller.scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: count,
            itemBuilder: (context, index) {
              final emp = controller.allEmployees[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EmployeeCard(
                  fullName: emp.fullName,
                  email: emp.email,
                  onClockIn: () => controller.openAttendanceDialog(
                    emp,
                    AttendanceDialogAction.clockIn,
                  ),
                  onClockOut: () => controller.openAttendanceDialog(
                    emp,
                    AttendanceDialogAction.clockOut,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.fullName,
    required this.email,
    required this.onClockIn,
    required this.onClockOut,
  });

  final String fullName;
  final String email;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullName.isEmpty ? '—' : fullName,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBrown,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              email.isEmpty ? '—' : email,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onClockIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Clock In',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClockOut,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.darkBrown,
                      side: const BorderSide(
                        color: AppColors.darkBrown,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Clock Out',
                      style: TextStyle(fontWeight: FontWeight.w600),
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
}
