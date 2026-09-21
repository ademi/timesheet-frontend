import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/client_onboarding_controller.dart';
import 'support_plan_specialist_section.dart';

class OnboardingSupportCoordinatorStep extends StatelessWidget {
  const OnboardingSupportCoordinatorStep({
    super.key,
    required this.controller,
  });

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = !controller.isSaving.value;
      final entry = controller.supportCoordinatorEntry;
      entry.revision.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Support Coordinator',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optional — one support coordinator. Separate from plan manager.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SupportPlanSpecialistSection(entry: entry, enabled: enabled),
        ],
      );
    });
  }
}
