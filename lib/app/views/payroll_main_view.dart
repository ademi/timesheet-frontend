import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_main_controller.dart';
import '../themes/app_colors.dart';

class PayrollMainView extends GetView<PayrollMainController> {
  const PayrollMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payroll'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ActionButton(
              icon: Icons.date_range_rounded,
              title: 'Periods',
              subtitle: 'Create, calculate, and close payroll periods',
              onTap: controller.openPeriods,
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.payments_rounded,
              title: 'Employee Rates',
              subtitle: 'View and manage pay rates by employee',
              onTap: () => controller.openEmployeeRates(context),
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Employee Balance',
              subtitle: 'View owed, paid, and outstanding balance',
              onTap: () => controller.openEmployeeBalance(context),
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.summarize_rounded,
              title: 'Summary Report',
              subtitle: 'Payroll summary by period or date range',
              onTap: controller.openSummaryReport,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cardBackground,
          foregroundColor: AppColors.darkBrown,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.darkBrown,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
