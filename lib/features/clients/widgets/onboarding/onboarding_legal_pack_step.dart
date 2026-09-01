import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../controllers/client_onboarding_controller.dart';

class OnboardingLegalPackStep extends StatelessWidget {
  const OnboardingLegalPackStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ackTemplate = controller.acknowledgementTemplate;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Legal pack',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload signed PDFs and mark each item complete. '
            'Consent and Service Agreement are selected by default.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          _LegalItem(
            title: 'Consent agreement',
            complete: controller.consentComplete.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller.consentSignerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Participant / representative name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                AsyncOutlinedButton(
                  onPressed: controller.markConsentComplete,
                  isLoading: controller.consentUploading.value,
                  child: Text(
                    controller.consentComplete.value
                        ? 'Re-upload consent'
                        : 'Upload PDF & mark complete',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LegalItem(
            title: 'Service agreement',
            complete: controller.serviceAgreementComplete.value,
            child: AsyncOutlinedButton(
              onPressed: controller.markServiceAgreementComplete,
              isLoading: controller.serviceAgreementUploading.value,
              child: Text(
                controller.serviceAgreementComplete.value
                    ? 'Re-upload service agreement'
                    : 'Upload PDF & mark complete',
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (controller.includeAcknowledgement.value ||
              controller.acknowledgementComplete.value) ...[
            _LegalItem(
              title: ackTemplate?.name ?? 'Participant acknowledgement',
              complete: controller.acknowledgementComplete.value,
              child: AsyncOutlinedButton(
                onPressed: controller.markAcknowledgementComplete,
                isLoading: controller.acknowledgementUploading.value,
                child: Text(
                  controller.acknowledgementComplete.value
                      ? 'Re-upload acknowledgement'
                      : 'Upload PDF & mark complete',
                ),
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed: () => controller.includeAcknowledgement.value = true,
              icon: const Icon(Icons.add),
              label: Text(
                ackTemplate != null
                    ? 'Add ${ackTemplate.name}'
                    : 'Add Acknowledgement (optional)',
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _LegalItem extends StatelessWidget {
  const _LegalItem({
    required this.title,
    required this.complete,
    required this.child,
  });

  final String title;
  final bool complete;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: complete ? AppColors.primary : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.check_circle : Icons.radio_button_unchecked,
                color: complete ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                complete ? 'Complete' : 'Missing',
                style: TextStyle(
                  fontSize: 12,
                  color: complete ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (!complete) ...[
            const SizedBox(height: 12),
            child,
          ],
        ],
      ),
    );
  }
}
