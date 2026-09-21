import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/app_date_field.dart';
import '../../controllers/support_plan_controller.dart';
import '../support_plan_clinical_section.dart';
import '../support_plan_form_widgets.dart';
import '../support_plan_sn_section.dart';

class SupportPlanReviewStep extends StatelessWidget {
  const SupportPlanReviewStep({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SupportPlanSectionTitle('Review'),
        const SizedBox(height: 12),
        Obx(
          () => Text(
            'Status: ${supportPlanFieldLabel(controller.status.value)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final goals = controller.goals.length;
          final hasRisk = controller.riskSummaryCtrl.text.trim().isNotEmpty ||
              controller.behavioursOfConcernCtrl.text.trim().isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goals: $goals',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Risk section: ${hasRisk ? 'filled' : 'empty'}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          );
        }),
        const SizedBox(height: 12),
        Obx(() {
          final next = controller.nextReviewAt.value;
          final parsed = DateTime.tryParse(next ?? '');
          final now = DateTime.now();
          return AppDateField(
            label: 'Next review date',
            value: parsed,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 5),
            initialDate: now,
            onChanged: (picked) {
              controller.nextReviewAt.value = formatAppDate(picked);
            },
          );
        }),
        const SizedBox(height: 24),
        const SupportPlanSectionTitle('Clinical pack'),
        const SizedBox(height: 12),
        SupportPlanClinicalSection(
          store: controller.clinical,
          clientId: controller.clientId,
        ),
        const SizedBox(height: 24),
        SupportPlanSnSection(
          planController: controller,
          clientId: controller.clientId,
        ),
      ],
    );
  }
}
