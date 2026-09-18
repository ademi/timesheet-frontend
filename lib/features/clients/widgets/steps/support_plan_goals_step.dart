import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../shared/widgets/other_text_field.dart';
import '../../controllers/support_plan_controller.dart';
import '../../utils/support_plan_keys.dart';
import '../support_plan_form_widgets.dart';

class SupportPlanGoalsStep extends StatelessWidget {
  const SupportPlanGoalsStep({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SupportPlanSectionTitle('Goals'),
        const SizedBox(height: 12),
        Obx(() {
          final list = controller.goals;
          return Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                SupportPlanGoalCard(
                  index: i,
                  ndisGoal: list[i].ndisGoal,
                  strategy: list[i].strategy,
                  measure: list[i].measure,
                  workerInstructions: list[i].workerInstructions,
                  onRemove: () => controller.removeGoal(i),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: list.length >= 20 ? null : controller.addGoal,
                  icon: const Icon(Icons.add),
                  label: const Text('Add goal'),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 24),
        const SupportPlanSectionTitle('Service categories'),
        const SizedBox(height: 12),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in SupportPlanController.categoryOptions)
                FilterChip(
                  label: Text(supportPlanFieldLabel(key)),
                  selected: controller.serviceCategories.contains(key),
                  onSelected: (_) => controller.toggleCategory(key),
                ),
            ],
          ),
        ),
        Obx(
          () => OtherTextField(
            isOther: controller.serviceCategories.contains(
              SupportPlanKeys.catOther,
            ),
            controller: controller.catOtherCtrl,
            label: 'Service category (other)',
          ),
        ),
      ],
    );
  }
}
