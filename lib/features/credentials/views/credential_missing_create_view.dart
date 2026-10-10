import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/views/widgets/app_back_button.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/app_toast.dart';
import '../controllers/credential_create_draft.dart';
import '../controllers/credentials_controller.dart';
import '../data/models/credential_models.dart';

/// Multi-section create flow: one form section per missing credential type.
class CredentialMissingCreateView extends StatefulWidget {
  const CredentialMissingCreateView({super.key});

  @override
  State<CredentialMissingCreateView> createState() =>
      _CredentialMissingCreateViewState();
}

class _CredentialMissingCreateViewState
    extends State<CredentialMissingCreateView> {
  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<CredentialsController>()) {
      Get.find<CredentialsController>().ensureMissingCreateFromRoute();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !Get.isRegistered<CredentialsController>()) return;
      Get.find<CredentialsController>().ensureMissingCreateFromRoute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CredentialsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRoute: AppRoutes.contractorCredentials,
        ),
        title: const Text('Add missing credentials'),
      ),
      body: Obx(() {
        // Depend on catalog load so help links appear.
        final _ = controller.catalogRevision.value;
        final types = controller.missingCreateTypes.toList();
        if (types.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No missing credentials to add.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Complete each missing credential below.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < types.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
                    _MissingCredentialSection(
                      type: types[i],
                      draft: controller.missingDrafts[types[i]],
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
}

class _MissingCredentialSection extends StatelessWidget {
  const _MissingCredentialSection({
    required this.type,
    required this.draft,
  });

  final String type;
  final CredentialCreateDraft? draft;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<CredentialsController>();
    final sectionDraft = draft;
    if (sectionDraft == null) return const SizedBox.shrink();

    final sensitive = isSensitiveCredentialType(type);
    final govId = isGovernmentIdCredentialType(type);
    final helpUrl = credentialTypeHelpUrl(type);

    return Obx(() {
      final err = sectionDraft.errorMessage.value;
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                credentialTypeLabel(type),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark,
                ),
              ),
              if (helpUrl != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        () => openExternalUrl(helpUrl).then((opened) {
                          if (!opened && context.mounted) {
                            AppToast.error(
                              'Could not open link',
                              'Try again or open the course in your browser.',
                            );
                          }
                        }),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Get this credential'),
                  ),
                ),
              ],
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
              const SizedBox(height: 16),
              TextField(
                controller: sectionDraft.issuerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Issuer (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sectionDraft.identifierCtrl,
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
              for (final document in sectionDraft.selectedEvidence)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    document.isScanClean
                        ? Icons.verified_outlined
                        : document.isScanBlocked
                        ? Icons.error_outline
                        : Icons.hourglass_top,
                  ),
                  title: Text(document.filename),
                  subtitle: Text(
                    document.isScanClean
                        ? 'Security scan: clean'
                        : document.isScanBlocked
                        ? 'Security scan: blocked'
                        : 'Security scan: ${document.scanStatus}…',
                  ),
                ),
              OutlinedButton.icon(
                onPressed:
                    sectionDraft.isUploadingEvidence.value
                        ? null
                        : () => controller.uploadEvidenceForMissing(type),
                icon: const Icon(Icons.upload_file),
                label: Text(
                  sectionDraft.isUploadingEvidence.value
                      ? 'Uploading…'
                      : sectionDraft.hasSelectedEvidence
                      ? 'Add another evidence file'
                      : 'Upload evidence file',
                ),
              ),
              if (sectionDraft.uploadProgress.value != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: sectionDraft.uploadProgress.value,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                ),
              ],
              if (sensitive) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: sectionDraft.sensitiveConsentConfirmed.value,
                  onChanged:
                      (v) =>
                          sectionDraft.sensitiveConsentConfirmed.value =
                              v ?? false,
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
                  value: sectionDraft.governmentIdAcknowledged.value,
                  onChanged:
                      (v) =>
                          sectionDraft.governmentIdAcknowledged.value =
                              v ?? false,
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
                    sectionDraft.isSaving.value ||
                            sectionDraft.isUploadingEvidence.value ||
                            !sectionDraft.hasCleanEvidenceReady
                        ? null
                        : () async {
                          final remaining = await controller
                              .createMissingCredential(type);
                          if (!context.mounted) return;
                          // null = failure; inline error is already shown.
                          if (remaining == null) return;
                          if (!remaining) {
                            Get.back();
                            AppToast.success(
                              'Created',
                              'All missing credentials saved with evidence.',
                            );
                          } else {
                            AppToast.success(
                              'Created',
                              '${credentialTypeLabel(type)} saved with evidence.',
                            );
                          }
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cta,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child:
                    sectionDraft.isSaving.value
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(
                          sectionDraft.hasPendingEvidenceScan
                              ? 'Waiting for scan…'
                              : 'Create',
                        ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
