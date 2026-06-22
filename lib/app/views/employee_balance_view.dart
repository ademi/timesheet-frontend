import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_balance_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class EmployeeBalanceView extends GetView<EmployeeBalanceController> {
  const EmployeeBalanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Employee Balance'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.balance.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final balance = controller.balance.value;
        if (balance == null) {
          return const Center(child: Text('No balance data available.'));
        }
        return RefreshIndicator(
          onRefresh: controller.loadBalance,
          child: MaxWidthBox(
            maxWidth: Breakpoints.maxContent,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
              _BalanceTile(
                label: 'Total Owed',
                value: balance.totalOwed,
                currency: balance.currencyCode,
              ),
              const SizedBox(height: 14),
              _BalanceTile(
                label: 'Total Paid',
                value: balance.totalPaid,
                currency: balance.currencyCode,
              ),
              const SizedBox(height: 14),
              _BalanceTile(
                label: 'Outstanding',
                value: balance.outstanding,
                currency: balance.currencyCode,
                highlight: balance.outstanding > 0,
              ),
            ],
          ),
          ),
        );
      }),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.value,
    required this.currency,
    this.highlight = false,
  });

  final String label;
  final double value;
  final String currency;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? AppColors.error.withValues(alpha: 0.08) : AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${value.toStringAsFixed(2)} $currency',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: highlight ? AppColors.error : AppColors.darkBrown,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
