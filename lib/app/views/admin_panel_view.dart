import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/token_storage.dart';
import '../../core/responsive/adaptive_grid.dart';
import '../constants/app_permissions.dart';
import '../controllers/admin_panel_controller.dart';
import '../controllers/auth_controller.dart';
import '../themes/app_colors.dart';
import '../widgets/admin_hub_card.dart';

class AdminPanelView extends GetView<AdminPanelController> {
  const AdminPanelView({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final storage = Get.find<TokenStorage>();
    final branchName = storage.branchName;

    final cards = <Widget>[
      if (storage.hasPermission(AppPermissions.employeesRead))
        AdminHubCard(
          icon: Icons.groups_rounded,
          title: 'Employees',
          subtitle: 'View staff, open profiles, and create employees',
          onTap: controller.openEmployees,
        ),
      if (storage.hasPermission(AppPermissions.attendanceView))
        AdminHubCard(
          icon: Icons.calendar_month_rounded,
          title: 'Attendance Report',
          subtitle: 'Weekly attendance grid and Excel export',
          onTap: controller.openAttendanceReport,
        ),
      if (storage.hasAnyPermission([
        AppPermissions.attendanceView,
        AppPermissions.attendanceOverride,
      ]))
        AdminHubCard(
          icon: Icons.rule_rounded,
          title: 'Attendance Corrections',
          subtitle: 'Review exceptions and fix missing punches',
          onTap: controller.openAttendanceCorrections,
        ),
      if (storage.hasAnyPermission([
        AppPermissions.schedulingRead,
        AppPermissions.schedulingManage,
      ]))
        AdminHubCard(
          icon: Icons.calendar_view_week_rounded,
          title: 'Shift Schedule',
          subtitle: 'View who works when, assignments, and leave',
          onTap: controller.openShiftSchedule,
        ),
      if (storage.hasPermission(AppPermissions.payrollView))
        AdminHubCard(
          icon: Icons.receipt_long_rounded,
          title: 'Payroll',
          subtitle: 'Periods, rates, balances, and payroll summary',
          onTap: controller.openPayroll,
        ),
      if (storage.hasPermission(AppPermissions.paymentsView))
        AdminHubCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Payments',
          subtitle: 'Record payments, reports, and payment history',
          onTap: controller.openPayments,
          accentColor: AppColors.primaryDark,
        ),
      if (storage.hasPermission(AppPermissions.auditView))
        AdminHubCard(
          icon: Icons.security_rounded,
          title: 'Security audit',
          subtitle: 'Recent auth and security events',
          onTap: controller.openAudit,
        ),
      if (storage.hasAnyPermission([
        AppPermissions.notificationsReceive,
        AppPermissions.notificationsManage,
      ]))
        AdminHubCard(
          icon: Icons.notifications_rounded,
          title: 'Notifications',
          subtitle: 'Tenant notification event feed',
          onTap: controller.openNotifications,
        ),
      if (storage.hasPermission(AppPermissions.geofenceRead))
        AdminHubCard(
          icon: Icons.fence_rounded,
          title: 'Geofence',
          subtitle: 'View configured geofence zones',
          onTap: controller.openGeofence,
        ),
      if (storage.hasPermission(AppPermissions.subscriptionView))
        AdminHubCard(
          icon: Icons.credit_card_rounded,
          title: 'Billing',
          subtitle: 'Subscription status and landing checkout link',
          onTap: controller.openBilling,
        ),
    ];

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
                    child: cards.isEmpty
                        ? const Center(
                            child: Text(
                              'No admin modules are available for your permissions.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : AdaptiveGrid(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            spacing: 14,
                            runSpacing: 14,
                            childAspectRatio: 2.2,
                            children: cards,
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
              color: AppColors.textLight.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded,
                color: AppColors.textLight),
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
                  style: TextStyle(
                    color: AppColors.textLight.withValues(alpha: 0.85),
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onChangeBranch,
            icon: const Icon(Icons.storefront_rounded, color: AppColors.textLight),
            tooltip: 'Change branch',
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: AppColors.textLight),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}
