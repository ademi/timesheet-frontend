import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/max_width_box.dart';
import '../controllers/credentials_controller.dart';
import '../data/models/credential_models.dart';

class CredentialCreateView extends GetView<CredentialsController> {
  const CredentialCreateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add credential')),
      body: Obx(() {
        final type = controller.selectedType.value;
        final sensitive = isSensitiveCredentialType(type);
        final govId = isGovernmentIdCredentialType(type);
        return MaxWidthBox(
          maxWidth: Breakpoints.narrowContent,
          child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (controller.errorMessage.value != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  controller.errorMessage.value!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Credential type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: type,
              items: [
                for (final t in controller.credentialTypeChoices)
                  DropdownMenuItem(
                    value: t,
                    child: Text(credentialTypeLabel(t)),
                  ),
              ],
              onChanged:
                  controller.isSaving.value || controller.hasSelectedEvidence
                      ? null
                      : (v) {
                        if (v == null) return;
                        controller.selectedType.value = v;
                        controller.sensitiveConsentConfirmed.value = false;
                        controller.governmentIdAcknowledged.value = false;
                      },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller.issuerCtrl,
              decoration: const InputDecoration(
                labelText: 'Issuer (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.identifierCtrl,
              decoration: InputDecoration(
                labelText:
                    govId
                        ? 'Identifier (masked at rest)'
                        : 'Identifier (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Evidence',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text('Evidence is required to save.'),
            const SizedBox(height: 8),
            for (final document in controller.selectedEvidence)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(document.filename),
                subtitle: Text('Security scan: ${document.scanStatus}'),
              ),
            OutlinedButton.icon(
              onPressed:
                  controller.isSaving.value
                      ? null
                      : controller.uploadEvidenceForCreate,
              icon: const Icon(Icons.upload_file),
              label: Text(
                controller.hasSelectedEvidence
                    ? 'Add another evidence file'
                    : 'Upload evidence file',
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
            if (sensitive) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.sensitiveConsentConfirmed.value,
                onChanged:
                    (v) =>
                        controller.sensitiveConsentConfirmed.value = v ?? false,
                title: const Text(
                  'I consent to collecting this sensitive credential '
                  'for engagement eligibility with this provider.',
                ),
              ),
            ],
            if (govId) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.governmentIdAcknowledged.value,
                onChanged:
                    (v) =>
                        controller.governmentIdAcknowledged.value = v ?? false,
                title: const Text(
                  'I understand government ID evidence is restricted and '
                  'downloaded only via a secure authenticated proxy '
                  '(not a public signed URL).',
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  controller.isSaving.value || !controller.hasSelectedEvidence
                      ? null
                      : () async {
                        final created = await controller.createCredential();
                        if (created != null) {
                          Get.back();
                          Get.snackbar(
                            'Created',
                            'Credential saved with evidence.',
                            snackPosition: SnackPosition.BOTTOM,
                            margin: const EdgeInsets.all(16),
                          );
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child:
                  controller.isSaving.value &&
                          controller.uploadProgress.value == null
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Create'),
            ),
          ],
        ),
        );
      }),
    );
  }
}
