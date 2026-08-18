import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../controllers/credentials_controller.dart';
import '../data/models/credential_models.dart';
import '../widgets/evidence_document_actions.dart';
import '../widgets/credential_status_chip.dart';

class CredentialDetailView extends GetView<CredentialsController> {
  const CredentialDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final arg = Get.arguments;
    final CredentialOut? credential =
        arg is CredentialOut ? arg : controller.selected;
    if (credential == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Credential')),
        body: const Center(child: Text('Credential not found.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(credentialTypeLabel(credential.credentialType)),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return ListView(
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
            _row('Evidence', credential.evidencePresence),
            if (controller.evidenceFor(credential).isNotEmpty) ...[
              const SizedBox(height: 8),
              EvidenceDocumentActions(
                documents: controller.evidenceFor(credential),
                isBusy: controller.isSaving.value,
                onView: (document) => controller.openEvidenceDocument(document),
                onDownload:
                    (document) => controller.openEvidenceDocument(
                      document,
                      download: true,
                    ),
              ),
            ],
            _row('Provenance', credential.provenanceState),
            if (credential.issuer != null) _row('Issuer', credential.issuer!),
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
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            if (isGovernmentIdCredentialType(credential.credentialType))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Government ID — downloads use /content proxy when required.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            const SizedBox(height: 24),
            if (controller.canManage) ...[
              ElevatedButton.icon(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.attachEvidence(credential),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  controller.isSaving.value
                      ? 'Uploading / scanning…'
                      : 'Attach evidence',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.supersede(credential),
                child: const Text('Supersede with new record'),
              ),
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
        );
      }),
    );
  }

  Widget _statusRow(String status) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 110,
            child: Text('Status', style: TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CredentialStatusChip(status: status),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
