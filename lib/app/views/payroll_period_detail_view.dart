import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_period_detail_controller.dart';
import '../themes/app_colors.dart';

class PayrollPeriodDetailView extends GetView<PayrollPeriodDetailController> {
  const PayrollPeriodDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Period Detail'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: Obx(() {
        final period = controller.period.value;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${controller.formatDate(period.periodStart)} → ${controller.formatDate(period.periodEnd)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Status: ${period.status}'),
                      if (period.closedAt != null)
                        Text(
                          'Closed: ${controller.formatDate(period.closedAt!)}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (period.status == 'open')
                _ActionButton(
                  label: 'Calculate',
                  icon: Icons.calculate,
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.calculatePeriod,
                ),
              if (period.status == 'calculated') ...[
                _ActionButton(
                  label: 'Close Period',
                  icon: Icons.lock_outline,
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.closePeriod,
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label: 'View Results',
                  icon: Icons.table_chart,
                  onPressed: controller.viewResults,
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label: 'Export CSV',
                  icon: Icons.download,
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.exportCsv,
                ),
              ],
              if (period.status == 'closed') ...[
                _ActionButton(
                  label: 'View Results',
                  icon: Icons.table_chart,
                  onPressed: controller.viewResults,
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  label: 'Export CSV',
                  icon: Icons.download,
                  onPressed: controller.isLoading.value
                      ? null
                      : controller.exportCsv,
                ),
              ],
              if (controller.isLoading.value) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textLight,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
