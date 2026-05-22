import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../bindings/payroll_module_binding.dart';
import '../controllers/admin_panel_controller.dart';
import '../controllers/attendance_report_controller.dart';
import '../controllers/auth_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/attendance_report_tab.dart';
import 'widgets/employee_management_tab.dart';

class AdminPanelView extends GetView<AdminPanelController> {
  const AdminPanelView({super.key});

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
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Admin Panel',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              PayrollModuleBinding.ensureDependencies();
              Get.toNamed(AppRoutes.payrollMain);
            },
            icon: const Icon(Icons.receipt_long, color: AppColors.primary),
            tooltip: 'Payroll',
          ),
          IconButton(
            onPressed: () => Get.toNamed(AppRoutes.paymentMain),
            icon: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
            tooltip: 'Payments',
          ),
          AnimatedBuilder(
            animation: controller.tabController,
            builder: (context, child) {
              if (controller.tabController.index == 1) {
                final reportController = Get.find<AttendanceReportController>();
                return Obx(() {
                  final hasData = reportController.reports.isNotEmpty;
                  return IconButton(
                    onPressed: hasData ? () => reportController.exportToExcel() : null,
                    icon: Icon(
                      Icons.file_download_outlined,
                      color: hasData ? AppColors.primary : AppColors.primary.withValues(alpha: 0.5),
                      size: 22,
                    ),
                    tooltip: 'Export to Excel',
                  );
                });
              }
              return const SizedBox.shrink();
            },
          ),
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
        bottom: TabBar(
          controller: controller.tabController,
          tabs: controller.tabs,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight.withValues(alpha: 0.6),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: TabBarView(
        controller: controller.tabController,
        children: const [EmployeeManagementTab(), AttendanceReportTab()],
      ),
    );
  }
}
