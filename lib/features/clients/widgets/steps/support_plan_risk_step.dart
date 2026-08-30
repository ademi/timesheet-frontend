import 'package:flutter/material.dart';

import '../../controllers/support_plan_controller.dart';
import '../support_plan_form_widgets.dart';

class SupportPlanRiskStep extends StatelessWidget {
  const SupportPlanRiskStep({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SupportPlanSectionTitle('Risk'),
        const SizedBox(height: 12),
        supportPlanField(controller.riskSummaryCtrl, 'Risk summary', maxLines: 2),
        const SizedBox(height: 12),
        supportPlanField(
          controller.behavioursOfConcernCtrl,
          'Behaviours of concern',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(controller.triggersCtrl, 'Triggers', maxLines: 2),
        const SizedBox(height: 12),
        supportPlanField(
          controller.deEscalationCtrl,
          'De-escalation',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        supportPlanField(
          controller.crisisResponseCtrl,
          'Crisis response',
          maxLines: 2,
        ),
        const SizedBox(height: 24),
        const SupportPlanSectionTitle('Schedule'),
        const SizedBox(height: 12),
        supportPlanField(controller.serviceDaysCtrl, 'Service days'),
        const SizedBox(height: 12),
        supportPlanField(controller.typicalTimesCtrl, 'Typical times'),
        const SizedBox(height: 12),
        supportPlanField(
          controller.recommendedHoursCtrl,
          'Recommended hours note',
          maxLines: 2,
        ),
      ],
    );
  }
}
