import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../controllers/support_plan_controller.dart';
import '../widgets/support_plan_clinical_section.dart';
import '../widgets/support_plan_consent_section.dart';
import '../widgets/support_plan_form_body.dart';
import '../widgets/support_plan_funding_section.dart';

class SupportPlanView extends GetView<SupportPlanController> {
  const SupportPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Support plan')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value ??
            controller.fundingConsent.errorMessage.value ??
            controller.clinical.errorMessage.value;
        final soft = controller.activateSoftWarning.value;
        final busy = controller.isBusy;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.reviewOverdue.value) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
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
                        SupportPlanFundingSection(
                          store: controller.fundingConsent,
                          clientId: controller.clientId,
                        ),
                        const SizedBox(height: 24),
                        SupportPlanConsentSection(
                          store: controller.fundingConsent,
                          clientId: controller.clientId,
                        ),
                        const SizedBox(height: 24),
                        SupportPlanClinicalSection(
                          store: controller.clinical,
                          clientId: controller.clientId,
                        ),
                        const SizedBox(height: 24),
                        SupportPlanFormBody(controller: controller),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (soft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FloatingErrorNotice(
                  message: soft,
                  onDismiss: () => controller.activateSoftWarning.value = null,
                ),
              ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FloatingErrorNotice(
                  message: err,
                  onDismiss: () {
                    controller.errorMessage.value = null;
                    controller.fundingConsent.errorMessage.value = null;
                    controller.clinical.errorMessage.value = null;
                  },
                ),
              ),
            FormStickyActions(
              onCancel: busy ? null : () => Get.back(),
              secondaryLabel: 'Save draft',
              onSecondary: busy ? null : () => controller.saveDraft(),
              primaryLabel: 'Activate',
              onPrimary:
                  !controller.canActivate || busy
                      ? null
                      : () => controller.activate(),
              isLoading: busy,
            ),
          ],
        );
      }),
    );
  }
}
