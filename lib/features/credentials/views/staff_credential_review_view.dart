import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/eligibility_incomplete_panel.dart';
import '../controllers/staff_credential_review_controller.dart';
import '../data/models/credential_models.dart';

class StaffCredentialReviewView
    extends GetView<StaffCredentialReviewController> {
  const StaffCredentialReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Credential review')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Metadata-only list for a contractor. Source file view stays '
              'behind grant + credentials.source.read (S4+).',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.contractorIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Contractor ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.engagementIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Engagement ID (for review actions)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason code (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed:
                    controller.isLoading.value ? null : controller.load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                child: const Text('Load credentials'),
              ),
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
            if (controller.mfaRequired.value) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDBA74)),
                ),
                child: const Text(
                  'MFA required for this review. Complete multi-factor '
                  'authentication for your staff session, then retry the decision.',
                ),
              ),
            ],
            if (controller.eligibilityReasons.isNotEmpty) ...[
              const SizedBox(height: 12),
              EligibilityIncompletePanel(
                reasons: controller.eligibilityReasons.toList(),
              ),
            ],
            const SizedBox(height: 16),
            if (controller.isLoading.value)
              const Center(child: CircularProgressIndicator())
            else if (controller.items.isEmpty)
              const Text('No credentials loaded.')
            else
              for (final c in controller.items) _StaffCredentialCard(c: c),
          ],
        );
      }),
    );
  }
}

class _StaffCredentialCard extends StatelessWidget {
  const _StaffCredentialCard({required this.c});

  final CredentialOut c;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffCredentialReviewController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              credentialTypeLabel(c.credentialType),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${c.status} · Evidence: ${c.evidencePresence}\n'
              'Provenance: ${c.provenanceState}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.submitReview(
                            credential: c,
                            decision: 'accepted',
                          ),
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.submitReview(
                            credential: c,
                            decision: 'rejected',
                          ),
                  child: const Text('Reject'),
                ),
                OutlinedButton(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.submitReview(
                            credential: c,
                            decision: 're_review_required',
                          ),
                  child: const Text('Re-review'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
