import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payment_main_controller.dart';
import '../themes/app_colors.dart';

class PaymentMainView extends GetView<PaymentMainController> {
  const PaymentMainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payments'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _ActionButton(
              icon: Icons.add_card_rounded,
              title: 'Create Payment',
              subtitle: 'Create and submit employee payment',
              onTap: controller.openCreatePayment,
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.table_chart_rounded,
              title: 'Payments Report',
              subtitle: 'Generate report by date, employee, and branch',
              onTap: controller.openPaymentsReport,
            ),
            const SizedBox(height: 14),
            _ActionButton(
              icon: Icons.history_edu_rounded,
              title: 'Employee Payment History',
              subtitle: 'Review historical payments by employee',
              onTap: controller.openEmployeeHistory,
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
