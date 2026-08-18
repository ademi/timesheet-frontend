import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/eligibility_incomplete_panel.dart';
import '../controllers/staff_credential_review_controller.dart';
import '../data/models/credential_models.dart';
import '../widgets/evidence_document_actions.dart';
import '../widgets/credential_status_chip.dart';

Color _reviewDecisionColor(String decision) {
  return switch (decision) {
    'accepted' => AppColors.success,
    'rejected' => AppColors.error,
    're_review_required' => const Color(0xFFEA580C),
    _ => AppColors.primary,
  };
}

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
              'Review each credential, then view or download its evidence '
              'file before you accept or reject it.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (!controller.hasReviewContext)
              const Text(
                'Open a person from Workforce to review their credentials.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed:
                    controller.isLoading.value || !controller.hasReviewContext
                        ? null
                        : controller.load,
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
                child: Text(
                  err,
                  style: const TextStyle(color: AppColors.error),
                ),
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
            else if (controller.needsShareRequest.value)
              _ShareRequestEmptyState(controller: controller)
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

class _ShareRequestEmptyState extends StatelessWidget {
  const _ShareRequestEmptyState({required this.controller});

  final StaffCredentialReviewController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'This contractor has not shared credentials with your organisation yet.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed:
              controller.isRequestingShare.value ||
                      !controller.hasReviewContext
                  ? null
                  : () => controller.requestAccess(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
          ),
          child:
              controller.isRequestingShare.value
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Request access'),
        ),
      ],
    );
  }
}

class _StaffCredentialCard extends StatelessWidget {
  const _StaffCredentialCard({required this.c});

  final CredentialOut c;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffCredentialReviewController>();
    return Obx(() {
      final reviewDecision = controller.reviewDecisionFor(c.id);
      final actions = controller.reviewActionsFor(c.id);
      final evidenceBusy = controller.isEvidenceBusy(c.id);
      final rejectReasonOpen = controller.isReasonPickerOpenFor(c.id, 'rejected');
      final reReviewReasonOpen = controller.isReasonPickerOpenFor(
        c.id,
        're_review_required',
      );
      final reasonPanelOpen = rejectReasonOpen || reReviewReasonOpen;
      final pendingDecision =
          rejectReasonOpen ? 'rejected' : reReviewReasonOpen ? 're_review_required' : null;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      credentialTypeLabel(c.credentialType),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  CredentialStatusChip(status: c.status),
                ],
              ),
              if (reviewDecision != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text(
                      'Your decision: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    CredentialStatusChip(status: reviewDecision),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Evidence: ${c.evidencePresence} · '
                'Provenance: ${c.provenanceState}',
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              EvidenceDocumentActions(
                documents: controller.evidenceFor(c),
                isBusy: evidenceBusy,
                showWhenEmpty: true,
                emptyMessage:
                    c.evidencePresence == 'present'
                        ? 'Evidence is on file, but the source file could not '
                            'be loaded. Retry Load credentials.'
                        : 'No evidence file attached.',
                onView:
                    (document) => controller.openEvidenceDocument(
                      document,
                      credentialId: c.id,
                    ),
                onDownload:
                    (document) => controller.openEvidenceDocument(
                      document,
                      credentialId: c.id,
                      download: true,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReviewActionButton(
                    label: 'Accept',
                    decision: 'accepted',
                    currentDecision: reviewDecision,
                    enabled: actions.acceptEnabled,
                    isLoading: controller.isReviewActionLoading(
                      c.id,
                      'accepted',
                    ),
                    onPressed:
                        () => controller.prepareReview(
                          credential: c,
                          decision: 'accepted',
                        ),
                  ),
                  _ReviewActionButton(
                    label: 'Reject',
                    decision: 'rejected',
                    currentDecision: reviewDecision,
                    enabled: actions.rejectEnabled,
                    isLoading: controller.isReviewActionLoading(
                      c.id,
                      'rejected',
                    ),
                    onPressed:
                        () => controller.prepareReview(
                          credential: c,
                          decision: 'rejected',
                        ),
                  ),
                  _ReviewActionButton(
                    label: 'Re-review',
                    decision: 're_review_required',
                    currentDecision: reviewDecision,
                    enabled: actions.reReviewEnabled,
                    isLoading: controller.isReviewActionLoading(
                      c.id,
                      're_review_required',
                    ),
                    onPressed:
                        () => controller.prepareReview(
                          credential: c,
                          decision: 're_review_required',
                        ),
                  ),
                ],
              ),
              if (reasonPanelOpen) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendingDecision == 'rejected'
                            ? 'Why are you rejecting this credential?'
                            : 'Why does this credential need re-review?',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Choose a reason so the contractor and staff team can '
                        'understand what needs to be fixed.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: controller.selectedReasonCode.value,
                        decoration: const InputDecoration(
                          labelText: 'Reason code',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Select a reason'),
                          ),
                          for (final option
                              in StaffCredentialReviewController.reasonCodeOptions)
                            DropdownMenuItem<String?>(
                              value: option.$1,
                              child: Text(option.$2),
                            ),
                        ],
                        onChanged: (v) => controller.selectedReasonCode.value = v,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AsyncElevatedButton(
                            onPressed:
                                controller.selectedReasonCode.value == null
                                    ? null
                                    : () => controller.confirmPendingReview(c),
                            isLoading: controller.isReviewActionLoading(
                              c.id,
                              pendingDecision!,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _reviewDecisionColor(pendingDecision),
                              foregroundColor: Colors.white,
                            ),
                            child: Text(
                              pendingDecision == 'rejected'
                                  ? 'Confirm reject'
                                  : 'Confirm re-review',
                            ),
                          ),
                          OutlinedButton(
                            onPressed: controller.clearPendingReason,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _ReviewActionButton extends StatelessWidget {
  const _ReviewActionButton({
    required this.label,
    required this.decision,
    required this.currentDecision,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final String decision;
  final String? currentDecision;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentDecision == decision;
    if (isSelected) {
      return AsyncElevatedButton(
        onPressed: enabled ? onPressed : null,
        isLoading: isLoading,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedColor(decision),
          foregroundColor: Colors.white,
          disabledBackgroundColor: _selectedColor(decision).withValues(
            alpha: 0.6,
          ),
          disabledForegroundColor: Colors.white,
        ),
        child: Text(label),
      );
    }
    return AsyncOutlinedButton(
      onPressed: enabled ? onPressed : null,
      isLoading: isLoading,
      child: Text(label),
    );
  }

  Color _selectedColor(String decision) {
    return _reviewDecisionColor(decision);
  }
}
