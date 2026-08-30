import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../controllers/contractor_register_controller.dart';
import '../widgets/register_step_widgets.dart';

class ContractorRegisterView extends GetView<ContractorRegisterController> {
  const ContractorRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          final i = controller.step.value;
          final label =
              i >= 0 && i < ContractorRegisterController.stepLabels.length
                  ? ContractorRegisterController.stepLabels[i]
                  : 'Register';
          return Text(label);
        }),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: RegisterStepIndicator(step: controller.step.value),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.step.value == 0) ...[
                          const Text(
                            'Create your contractor profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'After registering you will sign in and complete '
                            'any remaining onboarding steps.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        switch (controller.step.value) {
                          0 => RegisterIdentityStep(controller: controller),
                          1 => RegisterScreeningStep(controller: controller),
                          2 => RegisterQualificationsStep(
                            controller: controller,
                          ),
                          3 => RegisterChecksStep(controller: controller),
                          _ => RegisterLegalStep(controller: controller),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FloatingErrorNotice(
                  message: err,
                  onDismiss: () => controller.errorMessage.value = null,
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (controller.step.value == 0)
                        TextButton(
                          onPressed: controller.goToLogin,
                          child: const Text('Already have an account? Sign in'),
                        ),
                      Row(
                        children: [
                          if (controller.step.value > 0)
                            OutlinedButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : controller.previousStep,
                              child: const Text('Back'),
                            ),
                          const Spacer(),
                          AsyncElevatedButton(
                            onPressed: controller.nextStep,
                            isLoading: controller.isLoading.value ||
                                controller.isInviteLoading.value,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            child: Text(
                              controller.step.value ==
                                      ContractorRegisterController.maxStep
                                  ? 'Create account'
                                  : 'Next',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
