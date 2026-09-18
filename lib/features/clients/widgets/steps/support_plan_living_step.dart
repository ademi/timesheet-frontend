import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/other_text_field.dart';
import '../../controllers/support_plan_controller.dart';
import '../../utils/support_plan_keys.dart';
import '../support_plan_form_widgets.dart';

class SupportPlanLivingStep extends StatelessWidget {
  const SupportPlanLivingStep({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SupportPlanSectionTitle('Living'),
        const SizedBox(height: 12),
        Obx(
          () => DropdownButtonFormField<String>(
            initialValue: controller.residenceType.value,
            decoration: const InputDecoration(
              labelText: 'Residence type',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            items: [
              for (final v in SupportPlanController.residenceOptions)
                DropdownMenuItem(
                  value: v,
                  child: Text(supportPlanFieldLabel(v)),
                ),
            ],
            onChanged: (v) {
              if (v != null) controller.setResidenceType(v);
            },
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther:
                controller.residenceType.value == SupportPlanKeys.residenceOther,
            controller: controller.residenceOtherCtrl,
            label: 'Residence type (other)',
          ),
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.householdMembersCtrl,
          'Household members',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.informalSupportsCtrl,
          'Informal supports',
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        const SupportPlanSectionTitle('Preferences'),
        const SizedBox(height: 12),
        supportPlanField(
          controller.preferredSupportStyleCtrl,
          'Preferred support style',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(controller.routinesCtrl, 'Routines', maxLines: 2),
        const SizedBox(height: 12),
        supportPlanField(
          controller.interestsStrengthsCtrl,
          'Interests & strengths',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.culturalNotesCtrl,
          'Cultural notes',
          maxLines: 2,
        ),
      ],
    );
  }
}
