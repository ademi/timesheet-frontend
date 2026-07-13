import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/employee_rate_form_controller.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'shell/pane_tags.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class EmployeeRateFormView extends GetView<EmployeeRateFormController> {
  const EmployeeRateFormView({super.key, this.embedded = false, this.controllerTag});

  final bool embedded;
  final String? controllerTag;

  @override
  EmployeeRateFormController get controller =>
      Get.find<EmployeeRateFormController>(tag: controllerTag);

  @override
  Widget build(BuildContext context) {
    final title = controller.isEdit ? 'Edit Rate' : 'Create Rate';
    final form = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: embedded
          ? _buildFields(context)
          : MaxWidthBox(
              maxWidth: Breakpoints.formMaxWidth,
              child: _buildFields(context),
            ),
    );

    if (embedded) {
      return ColoredBox(
        color: AppColors.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EmbeddedHeader(title: title),
            Expanded(child: form),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.payrollEmployeeRates),
        title: Text(title),
        backgroundColor: AppColors.darkBrown,
      ),
      body: form,
    );
  }

  Widget _buildFields(BuildContext context) {
    return Column(
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Base Rate'),
          onEditingComplete: controller.applyBaseRateToDerivedRates,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.weekendRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weekend Rate'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.nightRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Night Rate'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.overtimeRateController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              foregroundColor: AppColors.onPrimary,
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
    );
  }
}

class EmployeeRateFormPane extends StatelessWidget {
  const EmployeeRateFormPane({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeRateFormView(
      embedded: true,
      controllerTag: PaneTags.rateForm,
    );
  }
}

class _EmbeddedHeader extends StatelessWidget {
  const _EmbeddedHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkBrown,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
