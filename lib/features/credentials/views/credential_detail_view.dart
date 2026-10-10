import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/views/widgets/app_back_button.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/humanize_label.dart';
import '../controllers/credentials_controller.dart';
import '../data/models/credential_models.dart';
import '../widgets/credential_provenance_chip.dart';
import '../widgets/credential_status_chip.dart';
import '../widgets/evidence_document_actions.dart';

class CredentialDetailView extends GetView<CredentialsController> {
  const CredentialDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final credential = controller.selectedRx.value;
      if (credential == null) {
        return Scaffold(
          appBar: AppBar(
            leading: const AppBackButton(
              fallbackRoute: AppRoutes.contractorCredentials,
            ),
            title: const Text('Credential'),
          ),
          body:
              controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(child: Text('Credential not found.')),
        );
      }

      final err = controller.errorMessage.value;
      final busy =
          controller.isUploadingEvidence.value || controller.isSaving.value;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: const AppBackButton(
            fallbackRoute: AppRoutes.contractorCredentials,
          ),
          title: Text(credential.displayLabel),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (err != null) ...[
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
                    const SizedBox(height: 12),
                  ],
                  _statusRow(credential.status),
                  _row('Evidence', humanizeLabel(credential.evidencePresence)),
                  if (controller.evidenceFor(credential).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    EvidenceDocumentActions(
                      documents: controller.evidenceFor(credential),
                      isBusy: busy,
                      onView:
                          (document) =>
                              controller.openEvidenceDocument(document),
                      onDownload:
                          (document) => controller.openEvidenceDocument(
                            document,
                            download: true,
                          ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _provenanceRow(
                    credentialReviewDisplayKey(
                      provenanceState: credential.provenanceState,
                      reviewDecision: credential.reviewDecision,
                    ),
                  ),
                  if (_shouldShowReviewReason(credential))
                    _row(
                      'Review reason',
                      credentialReviewReasonLabel(credential.reviewReasonCode),
                    ),
                  if (credential.issuer != null)
                    _row('Issuer', credential.issuer!),
                  if (credential.jurisdiction != null)
                    _row('Jurisdiction', credential.jurisdiction!),
                  if (credential.identifierMasked != null)
                    _row('Identifier', credential.identifierMasked!),
                  if (credential.expiresOn != null)
                    _row(
                      'Expires',
                      credential.expiresOn!.toIso8601String().split('T').first,
                    ),
                  if (isSensitiveCredentialType(credential.credentialType))
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'Sensitive credential — source access is grant-controlled.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (isGovernmentIdCredentialType(credential.credentialType))
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Government ID — downloads use /content proxy when required.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (controller.requiresNewReviewCycle(credential)) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Updating evidence creates a new submission for admin '
                      'review (Accept / Reject).',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (controller.canManage) ...[
                    ElevatedButton.icon(
                      onPressed:
                          busy
                              ? null
                              : () => controller.updateEvidence(credential),
                      icon: const Icon(Icons.upload_file),
                      label: Text(
                        controller.isUploadingEvidence.value
                            ? 'Uploading…'
                            : 'Update',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cta,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (controller.uploadProgress.value != null) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: controller.uploadProgress.value,
                        backgroundColor: AppColors.divider,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                  if (controller.lastScanStatus.value != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Scan status: ${controller.lastScanStatus.value}',
                      style: TextStyle(
                        color:
                            controller.lastScanStatus.value == 'blocked'
                                ? AppColors.error
                                : AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  bool _shouldShowReviewReason(CredentialOut credential) {
    final decision = credential.reviewDecision;
    if (decision != 'rejected' && decision != 're_review_required') {
      return false;
    }
    return credentialReviewReasonLabel(credential.reviewReasonCode).isNotEmpty;
  }

  Widget _statusRow(String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(
            width: 110,
            child: Text('Status', style: TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: CredentialStatusChip(status: status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _provenanceRow(String provenance) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 110,
            child: Text(
              'Review',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: CredentialProvenanceChip(provenance: provenance),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
