import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/markdown_viewer.dart';
import '../../credentials/controllers/credentials_controller.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../engagements/views/engagement_accept_panel.dart';
import '../controllers/onboarding_controller.dart';
import '../data/models/compliance_models.dart';

class OnboardingFunnelView extends GetView<OnboardingController> {
  const OnboardingFunnelView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contractor onboarding'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Column(
        children: [
          Obx(() => _ProgressHeader(stepIndex: controller.stepIndex.value)),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value &&
                  controller.legalDocs.isEmpty &&
                  controller.currentStep == OnboardingStep.legal) {
                return const Center(child: CircularProgressIndicator());
              }
              final err = controller.errorMessage.value;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (err != null) ...[
                    _ErrorBanner(message: err),
                    const SizedBox(height: 12),
                  ],
                  switch (controller.currentStep) {
                    OnboardingStep.legal => const _LegalStep(),
                    OnboardingStep.notices => const _NoticesStep(),
                    OnboardingStep.consents => const _ConsentsStep(),
                    OnboardingStep.engagement => const EngagementAcceptPanel(),
                    OnboardingStep.credentials => const _CredentialsStep(),
                  },
                ],
              );
            }),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Obx(
                () => Row(
                  children: [
                    if (controller.stepIndex.value > 0)
                      OutlinedButton(
                        onPressed: controller.back,
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed:
                          controller.isLoading.value ? null : controller.next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                      ),
                      child: Text(
                        controller.currentStep == OnboardingStep.credentials
                            ? 'Finish'
                            : 'Continue',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.stepIndex});

  final int stepIndex;

  static const labels = [
    'Legal',
    'Notices',
    'Consents',
    'Engagement',
    'Credentials',
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${stepIndex + 1} of ${labels.length}: ${labels[stepIndex]}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (stepIndex + 1) / labels.length,
                minHeight: 8,
                backgroundColor: AppColors.divider,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _LegalStep extends GetView<OnboardingController> {
  const _LegalStep();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.legalDocs.isEmpty) {
        return Column(
          children: [
            const Text('Loading legal documents…'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.loadLegal,
              child: const Text('Retry'),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Review and accept each document separately.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final doc in controller.legalDocs) ...[
            _DocCard(
              title: doc.docKey == 'platform_terms'
                  ? 'Platform Terms'
                  : 'Privacy Policy',
              meta: 'doc_key: ${doc.docKey} · version: ${doc.version}',
              markdown: doc.contentMd,
              counselPending: doc.counselPending,
              accepted: controller.acceptedDocKeys.contains(doc.docKey),
              onAccept: () => controller.acceptLegalDoc(doc),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    });
  }
}

class _NoticesStep extends GetView<OnboardingController> {
  const _NoticesStep();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.notices.isEmpty && !controller.isLoading.value) {
        return const Text(
          'No collection notices for AU right now. You can continue.',
          style: TextStyle(color: AppColors.textMuted),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Acknowledge each collection notice separately.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final n in controller.notices) ...[
            _DocCard(
              title: n.noticeKey,
              meta:
                  'credential: ${n.credentialType ?? "—"} · version: ${n.version}',
              markdown: n.contentMd,
              counselPending: n.counselPending,
              accepted: controller.acknowledgedNoticeKeys.contains(n.noticeKey),
              acceptLabel: 'I acknowledge this notice',
              onAccept: () => controller.acknowledgeNotice(n),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    });
  }
}

class _ConsentsStep extends GetView<OnboardingController> {
  const _ConsentsStep();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final needed = controller.notices
          .map((n) => n.credentialType)
          .whereType<String>()
          .where(sensitiveCredentialTypes.contains)
          .toSet()
          .toList()
        ..sort();
      final noticeByType = <String, CollectionNotice>{};
      for (final n in controller.notices) {
        final t = n.credentialType;
        if (t != null) noticeByType[t] = n;
      }
      if (needed.isEmpty) {
        return const Text(
          'No sensitive collection notices in the catalog for this '
          'jurisdiction. You can continue; consents will be required before '
          'creating those credential types.',
          style: TextStyle(color: AppColors.textMuted),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Sensitive credential types require an explicit consent '
            '(separate from Terms / Privacy).',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final type in needed) ...[
            Card(
              child: CheckboxListTile(
                value: controller.consentedTypes.contains(type),
                onChanged: controller.consentedTypes.contains(type)
                    ? null
                    : (_) => controller.consentToType(
                          type,
                          notice: noticeByType[type],
                        ),
                title: Text(type),
                subtitle: Text(
                  noticeByType[type] != null
                      ? 'Linked notice: ${noticeByType[type]!.noticeKey}'
                      : 'Consent without linked notice key',
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _StubStep extends StatelessWidget {
  const _StubStep({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(body, style: const TextStyle(color: AppColors.textMuted)),
      ],
    );
  }
}

class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CredentialsController>()) {
      return const _StubStep(
        title: 'Required credentials',
        body: 'Credentials module is not available in this session.',
      );
    }
    final c = Get.find<CredentialsController>();
    return Obx(() {
      final err = c.errorMessage.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required credentials',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create credentials from the allowlist and attach evidence. '
            'Wait for scan=clean before staff can accept.',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: c.isSaving.value
                    ? null
                    : () => Get.toNamed(AppRoutes.contractorCredentialCreate),
                icon: const Icon(Icons.add),
                label: const Text('Add credential'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
              OutlinedButton(
                onPressed: c.isLoading.value ? null : c.load,
                child: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (c.isLoading.value && c.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (c.items.isEmpty)
            const Text('No credentials yet.')
          else
            for (final item in c.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(credentialTypeLabel(item.credentialType)),
                subtitle: Text(
                  '${item.status} · evidence: ${item.evidencePresence}',
                ),
                trailing: IconButton(
                  tooltip: 'Attach evidence',
                  onPressed:
                      c.isSaving.value ? null : () => c.attachEvidence(item),
                  icon: const Icon(Icons.upload_file),
                ),
              ),
          if (c.lastScanStatus.value != null) ...[
            const SizedBox(height: 8),
            Text(
              'Last scan: ${c.lastScanStatus.value}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: c.lastScanStatus.value == 'blocked'
                    ? AppColors.error
                    : AppColors.textDark,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.title,
    required this.meta,
    required this.markdown,
    required this.counselPending,
    required this.accepted,
    required this.onAccept,
    this.acceptLabel = 'I accept this document',
  });

  final String title;
  final String meta;
  final String markdown;
  final bool counselPending;
  final bool accepted;
  final VoidCallback onAccept;
  final String acceptLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  meta,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (counselPending)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Counsel review pending — production may block this document.',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 160, child: MarkdownViewer(markdown: markdown)),
          const Divider(height: 1),
          if (accepted)
            const ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.success),
              title: Text('Recorded'),
            )
          else
            ListTile(
              title: Text(acceptLabel),
              trailing: FilledButton(
                onPressed: onAccept,
                child: const Text('Accept'),
              ),
            ),
        ],
      ),
    );
  }
}
