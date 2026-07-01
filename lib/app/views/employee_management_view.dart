import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_management_controller.dart';
import '../data/models/attendance/employee_model.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../utils/employee_clock_status.dart';
import 'employee_detail_view.dart';
import 'shell/two_pane.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class EmployeeManagementView extends GetView<EmployeeManagementController> {
  const EmployeeManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: const Text('Employees'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoPane = useTwoPaneLayout(constraints.maxWidth);

          if (!twoPane) {
            return MaxWidthBox(
              maxWidth: Breakpoints.maxContent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Obx(() => _buildList(useTwoPane: false)),
              ),
            );
          }

          return Obx(() {
            final selectedId = controller.selectedEmployeeId.value;
            return TwoPane(
              masterWidth: 360,
              master: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 0),
                child: _buildList(useTwoPane: true),
              ),
              detail: selectedId == null
                  ? const PaneDetailPlaceholder(
                      message: 'Select an employee to view details',
                      icon: Icons.person_outline_rounded,
                    )
                  : const EmployeeDetailPane(),
            );
          });
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.goToCreateEmployee,
        tooltip: 'Create Employee',
        heroTag: 'employee_management_create_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildList({required bool useTwoPane}) {
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
                final isSelected =
                    useTwoPane && controller.selectedEmployeeId.value == employee.id;
                return _EmployeeCard(
                  employee: employee,
                  statusLabel: controller.clockStatusLabel(employee),
                  isClockedIn: employee.clockedIn,
                  isSelected: isSelected,
                  onTap: () => controller.openEmployee(
                    employee,
                    useTwoPane: useTwoPane,
                  ),
                );
              },
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
    this.isSelected = false,
  });

  final EmployeeModel employee;
  final String statusLabel;
  final bool isClockedIn;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final subtitle = employeeContactSubtitle(employee);
    final statusColor =
        isClockedIn ? Colors.green.shade700 : Colors.grey.shade700;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.10)
            : AppColors.cardBackground,
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
                if (!isSelected)
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
