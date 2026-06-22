import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/responsive/adaptive_grid.dart';
import '../controllers/payment_main_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import '../widgets/admin_hub_card.dart';
import 'widgets/app_back_button.dart';

class PaymentMainView extends GetView<PaymentMainController> {
  const PaymentMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: const Text('Payments'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: AdaptiveGrid(
        padding: const EdgeInsets.all(20),
        spacing: 14,
        runSpacing: 14,
        children: [
          AdminHubCard(
            icon: Icons.add_card_rounded,
            title: 'Create Payment',
            subtitle: 'Create and submit employee payment',
            onTap: controller.openCreatePayment,
          ),
          AdminHubCard(
            icon: Icons.table_chart_rounded,
            title: 'Payments Report',
            subtitle: 'Generate report by date, employee, and branch',
            onTap: controller.openPaymentsReport,
          ),
          AdminHubCard(
            icon: Icons.history_edu_rounded,
            title: 'Employee Payment History',
            subtitle: 'Review historical payments by employee',
            onTap: controller.openEmployeeHistory,
          ),
        ],
      ),
    );
  }
}
