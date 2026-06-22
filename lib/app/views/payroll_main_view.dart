import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/responsive/adaptive_grid.dart';
import '../controllers/payroll_main_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../widgets/admin_hub_card.dart';
import 'widgets/app_back_button.dart';

class PayrollMainView extends GetView<PayrollMainController> {
  const PayrollMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: const Text('Payroll'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: AdaptiveGrid(
        padding: const EdgeInsets.all(20),
        spacing: 14,
        runSpacing: 14,
        children: [
          AdminHubCard(
            icon: Icons.date_range_rounded,
            title: 'Periods',
            subtitle: 'Create, calculate, and close payroll periods',
            onTap: controller.openPeriods,
          ),
          AdminHubCard(
            icon: Icons.settings_rounded,
            title: 'Payroll Settings',
            subtitle: 'Set schedule, defaults, and overlap validation',
            onTap: controller.openSettings,
          ),
          AdminHubCard(
            icon: Icons.payments_rounded,
            title: 'Employee Rates',
            subtitle: 'View and manage pay rates by employee',
            onTap: () => controller.openEmployeeRates(context),
          ),
          AdminHubCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Employee Balance',
            subtitle: 'View owed, paid, and outstanding balance',
            onTap: () => controller.openEmployeeBalance(context),
          ),
          AdminHubCard(
            icon: Icons.summarize_rounded,
            title: 'Summary Report',
            subtitle: 'Payroll summary by period or date range',
            onTap: controller.openSummaryReport,
          ),
        ],
      ),
    );
  }
}
