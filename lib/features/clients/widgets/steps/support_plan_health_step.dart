import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/other_text_field.dart';
import '../../../../shared/widgets/app_switch_field.dart';
import '../../controllers/support_plan_controller.dart';
import '../../utils/support_plan_keys.dart';
import '../support_plan_form_widgets.dart';

class SupportPlanHealthStep extends StatelessWidget {
  const SupportPlanHealthStep({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SupportPlanSectionTitle('Disability & health'),
        const SizedBox(height: 12),
        supportPlanField(controller.primaryDisabilityCtrl, 'Primary disability'),
        const SizedBox(height: 12),
        supportPlanField(
          controller.secondaryConditionsCtrl,
          'Secondary conditions',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.functionalImpactCtrl,
          'Functional impact summary',
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        const Text(
          'Functional limitations',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key
                  in SupportPlanController.functionalLimitationOptions)
                FilterChip(
                  label: Text(supportPlanFieldLabel(key)),
                  selected: controller.functionalLimitations.contains(key),
                  onSelected: (_) => controller.toggleLimitation(key),
                ),
            ],
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.functionalLimitations.contains(
              SupportPlanKeys.limitationOther,
            ),
            controller: controller.limitationOtherCtrl,
            label: 'Functional limitation (other)',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Communication methods',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in SupportPlanController.communicationOptions)
                FilterChip(
                  label: Text(supportPlanFieldLabel(key)),
                  selected: controller.communicationMethods.contains(key),
                  onSelected: (_) => controller.toggleCommunication(key),
                ),
            ],
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.communicationMethods.contains(
              SupportPlanKeys.commOther,
            ),
            controller: controller.commOtherCtrl,
            label: 'Communication method (other)',
          ),
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.mobilityNeedsCtrl,
          'Mobility needs',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.medicationScheduleCtrl,
          'Medication schedule',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: supportPlanField(controller.gpNameCtrl, 'GP name')),
            const SizedBox(width: 12),
            Expanded(child: supportPlanField(controller.gpPhoneCtrl, 'GP phone')),
          ],
        ),
        const SizedBox(height: 8),
        Obx(
          () => AppSwitchField(
            label: 'Behaviour support plan',
            value: controller.behaviourSupportPlan.value,
            onChanged: (v) => controller.behaviourSupportPlan.value = v,
          ),
        ),
        Obx(
          () => DropdownButtonFormField<String>(
            initialValue: controller.supportIntensity.value,
            decoration: const InputDecoration(
              labelText: 'Support intensity',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            items: [
              for (final v in SupportPlanController.intensityOptions)
                DropdownMenuItem(
                  value: v,
                  child: Text(supportPlanFieldLabel(v)),
                ),
            ],
            onChanged: (v) {
              if (v != null) controller.supportIntensity.value = v;
            },
          ),
        ),
      ],
    );
  }
}
