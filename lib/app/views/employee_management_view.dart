import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_management_controller.dart';
import '../data/models/attendance/employee_model.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../utils/employee_clock_status.dart';

class EmployeeManagementView extends GetView<EmployeeManagementController> {
  const EmployeeManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Employees'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Obx(() {
          controller.elapsedTicker.value;
          if (controller.isLoading.value && controller.employees.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: controller.fetchEmployees,
            child: controller.employees.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 140),
                      _EmptyState(),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.employees.length,
                    itemBuilder: (context, index) {
                      final employee = controller.employees[index];
                      return _EmployeeCard(
                        employee: employee,
                        statusLabel: controller.clockStatusLabel(employee),
                        isClockedIn: employee.clockedIn,
                        onTap: () async {
                          final result = await Get.toNamed(
                            AppRoutes.employeeDetail,
                            arguments: employee.id,
                          );
                          await controller.fetchEmployees();
                          if (result is String && result.isNotEmpty) {
                            Get.snackbar(
                              'Deleted',
                              result,
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: AppColors.success,
                              colorText: AppColors.textLight,
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.goToCreateEmployee,
        tooltip: 'Create Employee',
        heroTag: 'employee_management_create_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.statusLabel,
    required this.isClockedIn,
    required this.onTap,
  });

  final EmployeeModel employee;
  final String statusLabel;
  final bool isClockedIn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = employeeContactSubtitle(employee);
    final statusColor =
        isClockedIn ? Colors.green.shade700 : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    employee.fullName.isNotEmpty
                        ? employee.fullName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        employee.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (statusLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.group_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No employees yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull to refresh or tap + to create one.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
