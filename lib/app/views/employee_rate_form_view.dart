import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_rate_form_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

class EmployeeRateFormView extends GetView<EmployeeRateFormController> {
  const EmployeeRateFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final title = controller.isEdit ? 'Edit Rate' : 'Create Rate';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollEmployeeRates),
        title: Text(title),
        backgroundColor: AppColors.darkBrown,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Effective From'),
                subtitle: Text(
                  controller.effectiveFrom.value != null
                      ? controller.formatDate(controller.effectiveFrom.value!)
                      : 'Tap to select',
                ),
                trailing:
                    controller.isEdit ? null : const Icon(Icons.calendar_today),
                onTap: controller.isEdit
                    ? null
                    : () => controller.pickEffectiveFrom(context),
              ),
            ),
            Obx(
              () => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Effective To (optional)'),
                subtitle: Text(
                  controller.effectiveTo.value != null
                      ? controller.formatDate(controller.effectiveTo.value!)
                      : 'No end date',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.effectiveTo.value != null)
                      IconButton(
                        onPressed: controller.clearEffectiveTo,
                        icon: const Icon(Icons.close),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () => controller.pickEffectiveTo(context),
              ),
            ),
            TextField(
              controller: controller.baseRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Base Rate'),
              onEditingComplete: controller.applyBaseRateToDerivedRates,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.weekendRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weekend Rate'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.nightRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Night Rate'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.overtimeRateController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Overtime Rate'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.dailyThresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily OT Threshold (mins, optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.weeklyThresholdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weekly OT Threshold (mins, optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.nightShiftStartController,
              decoration: const InputDecoration(labelText: 'Night Start'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.nightShiftEndController,
              decoration: const InputDecoration(labelText: 'Night End'),
            ),
            const SizedBox(height: 24),
            Obx(
              () => ElevatedButton(
                onPressed: controller.isSaving.value ? null : controller.submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: controller.isSaving.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(controller.isEdit ? 'Update Rate' : 'Create Rate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
