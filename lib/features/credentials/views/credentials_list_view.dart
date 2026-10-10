import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../core/services/session_service.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../../shared/utils/humanize_label.dart';
import '../controllers/credentials_controller.dart';
import '../data/models/credential_models.dart';
import '../widgets/credential_provenance_chip.dart';
import '../widgets/credential_status_chip.dart';
import '../widgets/evidence_document_actions.dart';
import '../../engagements/bindings/engagements_binding.dart';
import '../../engagements/controllers/contractor_engagements_controller.dart';
import '../../engagements/widgets/engagement_docs_checklist.dart';

class CredentialsListView extends GetView<CredentialsController> {
  const CredentialsListView({super.key, this.embedded = false});

  /// When true (onboarding), omit shell AppBar chrome handled by parent.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    ContractorEngagementsController? engagements;
    if (Get.isRegistered<SessionService>()) {
      ContractorEngagementsBinding.ensure();
      if (Get.isRegistered<ContractorEngagementsController>()) {
        engagements = Get.find<ContractorEngagementsController>();
      }
    }

    final body = Obx(() {
      if (controller.isLoading.value && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final err = controller.errorMessage.value;

      // Determine whether the contractor has any engagement requesting docs.
      final engagementList = engagements?.items ?? [];
      final hasEngagements = engagementList.isNotEmpty;
      final pendingDocsEngagements = engagementList
          .where((e) => e.isPendingDocs || e.isAwaitingApproval)
          .toList(growable: false);
      final hasRequestedDocs =
          pendingDocsEngagements.isNotEmpty ||
          (Get.isRegistered<SessionService>() &&
              (Get.find<SessionService>().needsDocsAttention ||
                  Get.find<SessionService>().needsApprovalWait));
      // Allow adding if there's a doc request, or the contractor already has
      // credentials that may need updating (attach evidence / supersede).
      final canAdd =
          controller.canManage &&
          (hasRequestedDocs || controller.items.isNotEmpty);

      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (err != null) ...[
                    _Banner(message: err, error: true),
                    const SizedBox(height: 12),
                  ],
                  if (controller.lastScanStatus.value != null) ...[
                    _Banner(
                      message:
                          'Last evidence scan: ${controller.lastScanStatus.value}',
                      error: controller.lastScanStatus.value == 'blocked',
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    embedded
                        ? 'Add required credentials and attach evidence. '
                            'Scan must be clean before staff review.'
                        : 'Your credentials and evidence files.',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  if (engagements != null && hasRequestedDocs) ...[
                    const Text(
                      'Engagement document checklist',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final engagement in pendingDocsEngagements)
                      EngagementDocsChecklist(
                        engagement: engagement,
                        credentials: controller.items,
                        onAddMissing:
                            controller.canManage
                                ? (categories) {
                                  // Seed before push so create-missing survives
                                  // shell-tab re-enter races during navigation.
                                  controller.beginMissingCreate(categories);
                                  final types = categories
                                      .map((c) => c.trim())
                                      .where((c) => c.isNotEmpty)
                                      .toList(growable: false);
                                  AppNavigator.push(
                                    AppNavigator.location(
                                      AppRoutes
                                          .contractorCredentialCreateMissing,
                                      query: {'types': types.join(',')},
                                    ),
                                    extra: types,
                                  );
                                }
                                : null,
                      ),
                    const SizedBox(height: 4),
                  ],
                  if (canAdd)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          controller.clearMissingCreate();
                          AppNavigator.push(
                            AppRoutes.contractorCredentialCreate,
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add credential'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cta,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (controller.items.isEmpty) ...[
                    if (!hasEngagements)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: _NoEngagementNotice(),
                      )
                    else if (!hasRequestedDocs)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: _NoDocRequestNotice(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No credentials yet.'),
                      ),
                  ],
                  for (final c in controller.items)
                    _CredentialTile(credential: c),
                ],
              ),
            ),
          ],
        ),
      );
    });

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Credentials'),
        actions: shellAppBarActions(),
      ),
      body: body,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? AppColors.errorBackground : AppColors.slate200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: error ? AppColors.error : AppColors.textDark),
      ),
    );
  }
}

class _NoEngagementNotice extends StatelessWidget {
  const _NoEngagementNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.info_outline, color: AppColors.textMuted, size: 32),
        SizedBox(height: 8),
        Text(
          'No credentials requested yet.',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Credentials are added when an employer invites you and requests '
          'specific documents. Once you accept an engagement, any required '
          'credentials will appear here.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _NoDocRequestNotice extends StatelessWidget {
  const _NoDocRequestNotice();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Icon(Icons.check_circle_outline, color: AppColors.textMuted, size: 32),
        SizedBox(height: 8),
        Text(
          'No documents requested.',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Your employer hasn\'t requested any credentials yet. '
          'You\'ll be notified when documents are required.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _CredentialTile extends StatelessWidget {
  const _CredentialTile({required this.credential});

  final CredentialOut credential;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CredentialsController>();
    final hasEvidence = c.evidenceFor(credential).isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Text(credential.displayLabel),
                ),
                CredentialStatusChip(status: credential.status),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  'Evidence: ${humanizeLabel(credential.evidencePresence)}',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Review:',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    CredentialProvenanceChip(
                      provenance: credential.provenanceState,
                    ),
                  ],
                ),
                if (credential.identifierMasked != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${credential.identifierMasked}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'detail') c.openDetail(credential);
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(
                      value: 'detail',
                      child: Text('Details'),
                    ),
                  ],
            ),
            onTap: () => c.openDetail(credential),
          ),
          if (hasEvidence)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: EvidenceDocumentActions(
                documents: c.evidenceFor(credential),
                isBusy: c.isSaving.value || c.isUploadingEvidence.value,
                onView: (document) => c.openEvidenceDocument(document),
                onDownload:
                    (document) =>
                        c.openEvidenceDocument(document, download: true),
              ),
            ),
        ],
      ),
    );
  }
}
