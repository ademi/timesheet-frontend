import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/token_storage.dart';
import '../../core/responsive/adaptive_grid.dart';
import '../controllers/admin_panel_controller.dart';
import '../controllers/auth_controller.dart';
import '../themes/app_colors.dart';
import '../widgets/admin_hub_card.dart';

class AdminPanelView extends GetView<AdminPanelController> {
  const AdminPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final branchName = Get.find<TokenStorage>().branchName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdminHeader(
              branchName: branchName,
              onChangeBranch: controller.changeBranch,
              onLogout: authController.logout,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      'What would you like to manage?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: AdaptiveGrid(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        AdminHubCard(
                          icon: Icons.groups_rounded,
                          title: 'Employees',
                          subtitle:
                              'View staff, open profiles, and create employees',
                          onTap: controller.openEmployees,
                        ),
                        AdminHubCard(
                          icon: Icons.calendar_month_rounded,
                          title: 'Attendance Report',
                          subtitle: 'Weekly attendance grid and Excel export',
                          onTap: controller.openAttendanceReport,
                        ),
                        AdminHubCard(
                          icon: Icons.rule_rounded,
                          title: 'Attendance Corrections',
                          subtitle: 'Review exceptions and fix missing punches',
                          onTap: controller.openAttendanceCorrections,
                        ),
                        AdminHubCard(
                          icon: Icons.receipt_long_rounded,
                          title: 'Payroll',
                          subtitle: 'Periods, rates, balances, and payroll summary',
                          onTap: controller.openPayroll,
                        ),
                        AdminHubCard(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'Payments',
                          subtitle:
                              'Record payments, reports, and payment history',
                          onTap: controller.openPayments,
                          accentColor: AppColors.primaryDark,
                        ),
                      ],
                    ),
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
  const _AdminHeader({
    required this.branchName,
    required this.onChangeBranch,
    required this.onLogout,
  });

  final String? branchName;
  final VoidCallback onChangeBranch;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rostiq',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  branchName != null && branchName!.isNotEmpty
                      ? 'Administration · $branchName'
                      : 'Administration',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChangeBranch,
            icon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
            tooltip: 'Change branch',
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
