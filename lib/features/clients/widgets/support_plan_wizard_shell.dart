import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/support_plan_controller.dart';
import 'client_budget_remaining_section.dart';
import 'steps/support_plan_goals_step.dart';
import 'steps/support_plan_health_step.dart';
import 'steps/support_plan_living_step.dart';
import 'steps/support_plan_review_step.dart';
import 'steps/support_plan_risk_step.dart';
import 'support_plan_consent_section.dart';
import 'support_plan_form_widgets.dart';
import 'support_plan_funding_section.dart';

class SupportPlanWizardShell extends StatelessWidget {
  const SupportPlanWizardShell({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final step = controller.wizardStep.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.displayName.isNotEmpty)
            SupportPlanClientBanner(
              name: controller.displayName,
              ndis: controller.displayNdis,
            ),
          if (controller.displayName.isNotEmpty) const SizedBox(height: 12),
          Obx(() {
            if (!controller.needsBodyRepair.value) {
              return const SizedBox.shrink();
            }
            return const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SupportPlanRepairBanner(),
            );
          }),
          _SupportPlanStepIndicator(step: step),
          const SizedBox(height: 16),
          _buildStep(step),
        ],
      );
    });
  }

  Widget _buildStep(int step) {
    return switch (step) {
      0 => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SupportPlanFundingSection(
              store: controller.fundingConsent,
              clientId: controller.clientId,
            ),
            if (controller.canViewBudget)
              ClientBudgetRemainingSection(
                summary: controller.budgetSummary.value,
                isLoading: controller.isLoadingBudget.value,
              ),
          ],
        ),
      1 => SupportPlanConsentSection(
          store: controller.fundingConsent,
          clientId: controller.clientId,
        ),
      2 => SupportPlanHealthStep(controller: controller),
      3 => SupportPlanLivingStep(controller: controller),
      4 => SupportPlanGoalsStep(controller: controller),
      5 => SupportPlanRiskStep(controller: controller),
      _ => SupportPlanReviewStep(controller: controller),
    };
  }
}

class _SupportPlanStepIndicator extends StatelessWidget {
  const _SupportPlanStepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = SupportPlanController.wizardStepLabels;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        i <= step ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
