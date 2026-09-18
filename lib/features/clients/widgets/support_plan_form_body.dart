import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/support_plan_controller.dart';
import 'steps/support_plan_goals_step.dart';
import 'steps/support_plan_health_step.dart';
import 'steps/support_plan_living_step.dart';
import 'steps/support_plan_review_step.dart';
import 'steps/support_plan_risk_step.dart';
import 'support_plan_form_widgets.dart';

/// Full scroll view of all plan body steps (parity / fallback).
class SupportPlanFormBody extends StatelessWidget {
  const SupportPlanFormBody({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.displayName.isNotEmpty)
          SupportPlanClientBanner(
            name: controller.displayName,
            ndis: controller.displayNdis,
          ),
        Obx(() {
          if (!controller.needsBodyRepair.value) {
            return const SizedBox.shrink();
          }
          return const Padding(
            padding: EdgeInsets.only(top: 12),
            child: SupportPlanRepairBanner(),
          );
        }),
        const SizedBox(height: 16),
        SupportPlanHealthStep(controller: controller),
        const SizedBox(height: 24),
        SupportPlanLivingStep(controller: controller),
        const SizedBox(height: 24),
        SupportPlanGoalsStep(controller: controller),
        const SizedBox(height: 24),
        SupportPlanRiskStep(controller: controller),
        const SizedBox(height: 24),
        SupportPlanReviewStep(controller: controller),
        const SizedBox(height: 32),
      ],
    );
  }
}
