import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/employee_management_controller.dart';
import '../../themes/app_colors.dart';
import '../../utils/employee_clock_status.dart';

class EmployeeManagementTab extends GetView<EmployeeManagementController> {
  const EmployeeManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                      final subtitle = employeeContactSubtitle(employee);
                      final statusLabel = controller.clockStatusLabel(employee);
                      return _EmployeeCard(
                        fullName: employee.fullName,
                        employeeCode: employee.employeeCode,
                        phone: employee.phone,
                        subtitle: subtitle,
                        statusLabel: statusLabel,
                        isClockedIn: employee.clockedIn,
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
    required this.fullName,
    required this.employeeCode,
    required this.phone,
    required this.subtitle,
    required this.statusLabel,
    required this.isClockedIn,
  });

  final String fullName;
  final String employeeCode;
  final String phone;
  final String subtitle;
  final String statusLabel;
  final bool isClockedIn;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isClockedIn ? Colors.green.shade700 : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullName.isEmpty ? '--' : fullName,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _InfoRow(icon: Icons.badge_outlined, label: 'Code', value: employeeCode),
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: phone),
          ] else if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: subtitle,
            ),
          ],
          if (statusLabel.isNotEmpty) ...[
            const SizedBox(height: 10),
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '--' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.group_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No employees yet',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pull to refresh or tap "Create Employee".',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
