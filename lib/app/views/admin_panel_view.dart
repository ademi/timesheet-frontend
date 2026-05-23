import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/admin_panel_controller.dart';
import '../controllers/auth_controller.dart';
import '../themes/app_colors.dart';
import '../widgets/admin_hub_card.dart';

class AdminPanelView extends GetView<AdminPanelController> {
  const AdminPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdminHeader(onLogout: authController.logout),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text(
                    'What would you like to manage?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AdminHubCard(
                    icon: Icons.groups_rounded,
                    title: 'Employees',
                    subtitle: 'View staff, open profiles, and create employees',
                    onTap: controller.openEmployees,
                  ),
                  const SizedBox(height: 14),
                  AdminHubCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Attendance Report',
                    subtitle: 'Weekly attendance grid and Excel export',
                    onTap: controller.openAttendanceReport,
                  ),
                  const SizedBox(height: 14),
                  AdminHubCard(
                    icon: Icons.receipt_long_rounded,
                    title: 'Payroll',
                    subtitle: 'Periods, rates, balances, and payroll summary',
                    onTap: controller.openPayroll,
                  ),
                  const SizedBox(height: 14),
                  AdminHubCard(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Payments',
                    subtitle: 'Record payments, reports, and payment history',
                    onTap: controller.openPayments,
                    accentColor: AppColors.primaryDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      decoration: const BoxDecoration(
        color: AppColors.darkBrown,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yemen Gate',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Administration',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.primary),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}
