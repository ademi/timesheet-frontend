import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/client_onboarding_controller.dart';
import 'support_plan_specialists_panel.dart';

class OnboardingSupportSpecialistsStep extends StatelessWidget {
  const OnboardingSupportSpecialistsStep({
    super.key,
    required this.controller,
  });

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = !controller.isSaving.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Support Specialists',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optional — therapists and other specialists (not the coordinator).',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SupportPlanSpecialistsPanel(
            specialists: controller.supportSpecialists,
            enabled: enabled,
            onAdd:
                (context) => SupportPlanSpecialistsPanel.showTypePicker(
                  context,
                  onSelected: controller.addSupportSpecialist,
                ),
            onRemove: controller.removeSupportSpecialist,
          ),
        ],
      );
    });
  }
}
