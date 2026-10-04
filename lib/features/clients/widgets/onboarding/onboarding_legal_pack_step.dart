import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../shared/widgets/app_file_field.dart';
import '../../controllers/client_onboarding_controller.dart';
import '../../models/legal_other_document.dart';

class OnboardingLegalPackStep extends StatelessWidget {
  const OnboardingLegalPackStep({super.key, required this.controller});

  final ClientOnboardingController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ackTemplate = controller.acknowledgementTemplate;
      final canUpload = controller.canUploadDocs;
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
          if (!canUpload) ...[
            const SizedBox(height: 8),
            const Text(
              'Document upload is unavailable without documents.upload '
              'permission — PDF pickers are disabled.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
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
                AppFileField(
                  label: 'Consent PDF',
                  fileName:
                      controller.consentComplete.value ? 'On file' : null,
                  enabled:
                      canUpload && !controller.consentUploading.value,
                  onPick: () {
                    controller.markConsentComplete();
                  },
                  pickLabel:
                      controller.consentComplete.value
                          ? 'Re-upload'
                          : 'Choose file',
                  helperText:
                      controller.consentUploading.value
                          ? 'Uploading…'
                          : 'Upload PDF & mark complete',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LegalItem(
            title: 'Service agreement',
            complete: controller.serviceAgreementComplete.value,
            child: AppFileField(
              label: 'Service agreement PDF',
              fileName:
                  controller.serviceAgreementComplete.value ? 'On file' : null,
              enabled:
                  canUpload && !controller.serviceAgreementUploading.value,
              onPick: () {
                controller.markServiceAgreementComplete();
              },
              pickLabel:
                  controller.serviceAgreementComplete.value
                      ? 'Re-upload'
                      : 'Choose file',
              helperText:
                  controller.serviceAgreementUploading.value
                      ? 'Uploading…'
                      : 'Upload PDF & mark complete',
            ),
          ),
          const SizedBox(height: 12),
          if (controller.includeAcknowledgement.value ||
              controller.acknowledgementComplete.value) ...[
            _LegalItem(
              title: ackTemplate?.name ?? 'Participant acknowledgement',
              complete: controller.acknowledgementComplete.value,
              child: AppFileField(
                label: 'Acknowledgement PDF',
                fileName:
                    controller.acknowledgementComplete.value
                        ? 'On file'
                        : null,
                enabled:
                    canUpload && !controller.acknowledgementUploading.value,
                onPick: () {
                  controller.markAcknowledgementComplete();
                },
                pickLabel:
                    controller.acknowledgementComplete.value
                        ? 'Re-upload'
                        : 'Choose file',
                helperText:
                    controller.acknowledgementUploading.value
                        ? 'Uploading…'
                        : 'Upload PDF & mark complete',
              ),
            ),
          ] else ...[
            OutlinedButton.icon(
              onPressed:
                  canUpload
                      ? () => controller.includeAcknowledgement.value = true
                      : null,
              icon: const Icon(Icons.add),
              label: Text(
                ackTemplate != null
                    ? 'Add ${ackTemplate.name}'
                    : 'Add Acknowledgement (optional)',
              ),
            ),
          ],
          for (final row in controller.legalOtherDocs) ...[
            const SizedBox(height: 12),
            _LegalOtherItem(controller: controller, row: row),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: canUpload ? controller.addLegalOtherDoc : null,
            icon: const Icon(Icons.add),
            label: const Text('Add a document'),
          ),
        ],
      );
    });
  }
}

class _LegalOtherItem extends StatelessWidget {
  const _LegalOtherItem({required this.controller, required this.row});

  final ClientOnboardingController controller;
  final LegalOtherDocumentDraft row;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final title =
          row.displayLabel ?? legalOtherTypePresets[row.typeKey] ?? 'Document';
      // Subscribe so Choose/Re-upload disable while upload is in flight.
      final uploading = controller.legalOtherUploading.contains(row.id);
      controller.legalOtherDocs.length;
      return _LegalItem(
        title: title,
        complete: row.complete,
        // Legal-other rows stay editable so users can remove / re-upload.
        lockWhenComplete: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: legalOtherTypePresets.containsKey(row.typeKey)
                  ? row.typeKey
                  : 'other',
              decoration: const InputDecoration(
                labelText: 'Document type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in legalOtherTypePresets.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: uploading
                  ? null
                  : (v) {
                      if (v == null) return;
                      row.typeKey = v;
                      if (v != 'other') {
                        row.customLabel = null;
                      }
                      controller.legalOtherDocs.refresh();
                    },
            ),
            if (row.typeKey == 'other') ...[
              const SizedBox(height: 8),
              TextFormField(
                key: ValueKey('legal-other-name-${row.id}'),
                initialValue: row.customLabel ?? '',
                enabled: !uploading,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  row.customLabel = v;
                  controller.legalOtherDocs.refresh();
                },
              ),
            ],
            const SizedBox(height: 8),
            AppFileField(
              label: 'Document PDF',
              fileName: row.fileName ?? (row.complete ? 'On file' : null),
              enabled: controller.canUploadDocs && !uploading,
              onPick: () {
                controller.markLegalOtherComplete(row.id);
              },
              pickLabel: row.complete ? 'Re-upload' : 'Choose file',
              helperText:
                  uploading ? 'Uploading…' : 'Upload PDF & mark complete',
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: uploading
                    ? null
                    : () => controller.removeLegalOtherDoc(row.id),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _LegalItem extends StatelessWidget {
  const _LegalItem({
    required this.title,
    required this.complete,
    required this.child,
    this.lockWhenComplete = true,
  });

  final String title;
  final bool complete;
  final Widget child;

  /// When true (Consent / SA / Ack), hide controls after complete.
  /// Legal-other rows pass false so Remove / Re-upload stay available.
  final bool lockWhenComplete;

  @override
  Widget build(BuildContext context) {
    final showChild = !complete || !lockWhenComplete;
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
          if (showChild) ...[const SizedBox(height: 12), child],
        ],
      ),
    );
  }
}
