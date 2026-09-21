import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/app_switch_field.dart';
import '../../controllers/client_onboarding_controller.dart';
import '../support_plan_clinical_section.dart';

class OnboardingCarePlanStep extends StatelessWidget {
  const OnboardingCarePlanStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = !controller.isSaving.value;
      final id = controller.clientId ?? '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Care plan',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optional for day-one — allergies, clinical docs, and share flags.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.allergiesCtrl,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Allergies (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.primaryDisabilityCtrl,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Primary disability (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.supportPlanOtherCtrl,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Care notes (optional)',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          if (id.isNotEmpty)
            SupportPlanClinicalSection(
              store: controller.clinical,
              clientId: id,
            ),
          const SizedBox(height: 16),
          const Text(
            'Consent flags',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          AppSwitchField(
            label: 'Information share',
            subtitle: 'Information may be shared with relevant providers',
            value: controller.infoShareConsent.value,
            onChanged:
                enabled ? (v) => controller.infoShareConsent.value = v : null,
          ),
          const SizedBox(height: 8),
          AppSwitchField(
            label: 'Specific supports',
            subtitle: 'Consent for specific support delivery',
            value: controller.specificSupportsConsent.value,
            onChanged:
                enabled
                    ? (v) => controller.specificSupportsConsent.value = v
                    : null,
          ),
        ],
      );
    });
  }
}
