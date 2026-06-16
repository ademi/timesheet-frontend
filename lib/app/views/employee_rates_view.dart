import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_rates_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class EmployeeRatesView extends GetView<EmployeeRatesController> {
  const EmployeeRatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollMain),
        title: const Text('Employee Rates'),
        backgroundColor: AppColors.darkBrown,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.openCreateForm,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.rates.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.rates.isEmpty) {
          return const Center(child: Text('No rates for this employee yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: controller.rates.length,
          itemBuilder: (context, index) {
            final rate = controller.rates[index];
            final toLabel = rate.effectiveTo != null
                ? controller.formatDate(rate.effectiveTo!)
                : 'ongoing';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(
                  '${controller.formatDate(rate.effectiveFrom)} → $toLabel',
                ),
                subtitle: Text(
                  'Base: ${rate.baseRate} | Weekend: ${rate.weekendRate} | Night: ${rate.nightRate}',
                ),
                onTap: () => controller.openEditForm(rate),
              ),
            );
          },
        );
      }),
    );
  }
}
