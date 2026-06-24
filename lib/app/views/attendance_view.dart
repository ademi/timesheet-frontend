import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/token_storage.dart';
import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../utils/employee_clock_status.dart';
import '../themes/app_colors.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final branchName = Get.find<TokenStorage>().branchName;

    return PopScope(
      canPop: false,
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.darkBrown,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ShiftMate',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              branchName != null && branchName.isNotEmpty
                  ? 'Attendance · $branchName'
                  : 'Attendance',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                letterSpacing: 0.7,
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Obx(() {
          controller.elapsedTicker.value;
          if (controller.employeesLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.allEmployees.isEmpty) {
            return const Center(
              child: Text(
                'No employees yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            );
          }

          final count = controller.visibleCount.value;
          return MaxWidthBox(
            maxWidth: Breakpoints.maxContent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Single column on mobile; 3 cards per row on tablet/desktop/web.
                final isWide = constraints.maxWidth >= Breakpoints.phone;

                if (!isWide) {
                  return ListView.builder(
                    controller: controller.scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    itemCount: count,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildEmployeeCard(index),
                      );
                    },
                  );
                }

                return GridView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: count,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 150,
                  ),
                  itemBuilder: (context, index) => _buildEmployeeCard(index),
                );
              },
            ),
          );
        }),
      ),
    ),
    );
  }

  Widget _buildEmployeeCard(int index) {
    final emp = controller.allEmployees[index];
    return _EmployeeCard(
      fullName: emp.fullName,
      subtitle: employeeContactSubtitle(emp),
      isClockedIn: emp.clockedIn,
      isClockedOut: emp.clockedOut,
      durationText: controller.formatClockedInDuration(emp),
      onClockIn: () => controller.openAttendanceDialog(
        emp,
        AttendanceDialogAction.clockIn,
      ),
      onClockOut: () => controller.openAttendanceDialog(
        emp,
        AttendanceDialogAction.clockOut,
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.fullName,
    required this.subtitle,
    required this.isClockedIn,
    required this.isClockedOut,
    required this.durationText,
    required this.onClockIn,
    required this.onClockOut,
  });

  final String fullName;
  final String subtitle;
  final bool isClockedIn;
  final bool isClockedOut;
  final String durationText;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fullName.isEmpty ? '—' : fullName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.darkBrown,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
            if (isClockedIn && durationText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Clocked in for $durationText',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildAttendanceActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceActions() {
    //final attendedToday = isClockedIn && isClockedOut;
    //if (attendedToday) {
    //  return Container(
    //    width: double.infinity,
    //    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    //    decoration: BoxDecoration(
    //      color: AppColors.success.withValues(alpha: 0.12),
    //      borderRadius: BorderRadius.circular(12),
    //      border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
    //    ),
    //    child: const Text(
    //      'Employee has attended today',
    //      textAlign: TextAlign.center,
    //      style: TextStyle(
    //        color: AppColors.success,
    //        fontSize: 13,
    //        fontWeight: FontWeight.w600,
    //      ),
    //    ),
    //  );
    //}

    final showClockIn = !isClockedIn;
    //final showClockOut = !isClockedOut;

    //if (showClockIn && showClockOut) {
    //  return Row(
    //    children: [
    //      Expanded(child: _buildClockInButton()),
    //      const SizedBox(width: 10),
    //      Expanded(child: _buildClockOutButton()),
    //    ],
    //  );
    //}

    return SizedBox(
      width: double.infinity,
      child: showClockIn ? _buildClockInButton() : _buildClockOutButton(),
    );
  }

  Widget _buildClockInButton() {
    return ElevatedButton(
      onPressed: onClockIn,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Clock In',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildClockOutButton() {
    return OutlinedButton(
      onPressed: onClockOut,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.darkBrown,
        side: const BorderSide(color: AppColors.darkBrown, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Clock Out',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
