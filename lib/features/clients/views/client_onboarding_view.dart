import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../controllers/client_onboarding_controller.dart';
import '../widgets/onboarding/onboarding_address_step.dart';
import '../widgets/onboarding/onboarding_contacts_step.dart';
import '../widgets/onboarding/onboarding_funding_step.dart';
import '../widgets/onboarding/onboarding_identity_step.dart';
import '../widgets/onboarding/onboarding_legal_pack_step.dart';
import '../widgets/onboarding/onboarding_preferences_step.dart';
import '../widgets/onboarding/onboarding_representative_step.dart';

class ClientOnboardingView extends GetView<ClientOnboardingController> {
  const ClientOnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          final i = controller.step.value;
          final label =
              i >= 0 && i < ClientOnboardingController.stepLabels.length
                  ? ClientOnboardingController.stepLabels[i]
                  : 'Onboarding';
          return Text(label);
        }),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _StepIndicator(step: controller.step.value),
            ),
            if (controller.client.value != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ClientBanner(name: controller.client.value!.fullName),
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
                        switch (controller.step.value) {
                          0 => OnboardingIdentityStep(controller: controller),
                          1 => OnboardingAddressStep(controller: controller),
                          2 => OnboardingPreferencesStep(
                            controller: controller,
                          ),
                          3 => OnboardingContactsStep(controller: controller),
                          4 => OnboardingRepresentativeStep(
                            controller: controller,
                          ),
                          5 => OnboardingFundingStep(controller: controller),
                          _ => OnboardingLegalPackStep(controller: controller),
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
                  child: Obx(() {
                    final isLast =
                        controller.step.value ==
                        ClientOnboardingController.maxStep;
                    final skipCarer = controller.showSkipCarer;
                    final skipContacts = controller.showSkipContacts;
                    final skipNominee = controller.showSkipNominee;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (skipContacts)
                          TextButton(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : controller.skipContacts,
                            child: const Text('Skip contacts'),
                          ),
                        if (skipCarer)
                          TextButton(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : controller.skipCarer,
                            child: const Text('Skip carer'),
                          ),
                        if (skipNominee)
                          TextButton(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : controller.skipNominee,
                            child: const Text('Skip nominee'),
                          ),
                        Row(
                          children: [
                            if (controller.step.value > 0)
                              OutlinedButton(
                                onPressed:
                                    controller.isSaving.value
                                        ? null
                                        : controller.previousStep,
                                child: const Text('Back'),
                              ),
                            const Spacer(),
                            AsyncElevatedButton(
                              onPressed: controller.nextStep,
                              isLoading: controller.isSaving.value,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                              ),
                              child: Text(isLast ? 'Finish' : 'Next'),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ClientOnboardingController.stepLabels;
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
                    color: i <= step ? AppColors.textDark : AppColors.textMuted,
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

class _ClientBanner extends StatelessWidget {
  const _ClientBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    );
  }
}
