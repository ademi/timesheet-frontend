import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../credentials/data/models/credential_models.dart';
import '../bindings/engagements_binding.dart';
import '../controllers/contractor_engagements_controller.dart';
import '../data/models/engagement_models.dart';

/// Embedded in onboarding or shown standalone.
class EngagementAcceptPanel extends GetView<ContractorEngagementsController> {
  const EngagementAcceptPanel({super.key});

  @override
  ContractorEngagementsController get controller {
    // Permanent when registered via onboarding; still ensure for standalone use.
    ContractorEngagementsBinding.ensure(permanent: true);
    return Get.find<ContractorEngagementsController>();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final err = controller.errorMessage.value;
      final accepting = controller.accepting.value;

      if (accepting != null) {
        return _GrantForm(engagement: accepting);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accept engagement',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accepting authorises sharing credential metadata with the '
            'provider. If documents are required, upload them later from '
            'the home banner or Credentials.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          if (err != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(err, style: const TextStyle(color: AppColors.error)),
            ),
          ],
          const SizedBox(height: 12),
          if (controller.isLoading.value && controller.items.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (controller.invited.isEmpty)
            Text(
              controller.items.isEmpty
                  ? 'No engagements yet. Ask your provider to invite you.'
                  : 'No invited engagements waiting for accept. '
                      'Current: ${controller.items.map((e) => e.status).join(", ")}.',
              style: const TextStyle(color: AppColors.textMuted),
            )
          else
            for (final e in controller.invited)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    e.tenantName?.isNotEmpty == true
                        ? e.tenantName!
                        : 'Provider ${e.tenantId}',
                  ),
                  subtitle: Text(
                    'Status: ${e.status}\n'
                    'Required: ${e.requiredDocCategories.map((c) => credentialTypeLabel(c.category)).join(", ").ifEmpty("—")}',
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    onPressed: () => controller.beginAccept(e),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: controller.isLoading.value ? null : controller.load,
              child: const Text('Refresh'),
            ),
          ),
        ],
      );
    });
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class _GrantForm extends GetView<ContractorEngagementsController> {
  const _GrantForm({required this.engagement});

  final EngagementOut engagement;

  @override
  ContractorEngagementsController get controller {
    ContractorEngagementsBinding.ensure(permanent: true);
    return Get.find<ContractorEngagementsController>();
  }

  @override
  Widget build(BuildContext context) {
    final provider =
        engagement.tenantName?.isNotEmpty == true
            ? engagement.tenantName!
            : 'this provider';

    return Obx(() {
      final err = controller.errorMessage.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share with $provider',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are authorising $provider to receive credential '
            'metadata needed for this engagement '
            '(${engagement.requiredDocCategories.map((c) => c.category).join(", ").ifEmpty("required documents")}). '
            'If documents are required, upload them later from the home '
            'banner or Credentials.',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          if (err != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(err, style: const TextStyle(color: AppColors.error)),
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.allowSourceEvidence.value,
            onChanged: (v) => controller.allowSourceEvidence.value = v,
            title: const Text('Allow source evidence access'),
            subtitle: const Text(
              'When on, this provider may view underlying document files '
              '(not only metadata), subject to grants and permissions. '
              'Leave off unless the provider needs to sight originals.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.understoodWithdrawEffects.value,
            onChanged:
                (v) => controller.understoodWithdrawEffects.value = v ?? false,
            title: const Text(
              'I understand that withdrawing consent or ending this '
              'engagement blocks future platform-mediated access. The '
              'provider may retain lawful copies already obtained.',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed:
                    controller.isSaving.value ? null : controller.cancelAccept,
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.confirmAccept(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child:
                    controller.isSaving.value
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Confirm accept'),
              ),
            ],
          ),
        ],
      );
    });
  }
}
