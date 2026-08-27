import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/support_plan_controller.dart';
import 'support_plan_form_body.dart';

class ClientDetailCarePlanSection extends StatelessWidget {
  const ClientDetailCarePlanSection({super.key, required this.controller});

  final SupportPlanController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.reviewOverdue.value) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.openSlotBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.openSlot),
              ),
              child: const Text(
                'Review overdue',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.openSlot,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SupportPlanFormBody(controller: controller),
        ],
      );
    });
  }
}
