import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/payroll_periods_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class PayrollPeriodsView extends GetView<PayrollPeriodsController> {
  const PayrollPeriodsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Payroll Periods'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Payroll Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.openCreatePeriodSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.periods.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.periods.isEmpty) {
          return const Center(child: Text('No payroll periods yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.periods.length,
          itemBuilder: (context, index) {
            final period = controller.periods[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  '${controller.formatDate(period.periodStart)} → ${controller.formatDate(period.periodEnd)}',
                ),
                subtitle: Text('Status: ${period.status}'),
                trailing: Chip(
                  label: Text(
                    period.status,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: controller.statusColor(period.status),
                ),
                onTap: () => controller.openPeriodDetail(period),
              ),
            );
          },
        );
      }),
    );
  }
}
