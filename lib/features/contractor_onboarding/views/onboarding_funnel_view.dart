import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/markdown_viewer.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../engagements/views/engagement_accept_panel.dart';
import '../bindings/onboarding_binding.dart';
import '../controllers/onboarding_controller.dart';
import '../data/models/compliance_models.dart';

class OnboardingFunnelView extends GetView<OnboardingController> {
  const OnboardingFunnelView({super.key});

  /// Ensure binding ran (covers hot reload / route-replace races).
  @override
  OnboardingController get controller {
    OnboardingBinding.ensure();
    return Get.find<OnboardingController>();
  }

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
                    // Credentials are managed under the contractor Credentials tab.
                    OnboardingStep.credentials => const SizedBox.shrink(),
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
                    AsyncElevatedButton(
                      onPressed:
                          controller.canAdvanceCurrentStep
                              ? controller.next
                              : null,
                      isLoading:
                          controller.isLoading.value ||
                          controller.hasPendingAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                      ),
                      child: Text(
                        controller.nextFinishesFunnel ? 'Finish' : 'Continue',
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
  ];

  @override
  Widget build(BuildContext context) {
    final displayIndex = stepIndex.clamp(0, labels.length - 1);
    return Material(
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${displayIndex + 1} of ${labels.length}: '
              '${labels[displayIndex]}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (displayIndex + 1) / labels.length,
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

class _LegalStep extends StatefulWidget {
  const _LegalStep();

  @override
  State<_LegalStep> createState() => _LegalStepState();
}

class _LegalStepState extends State<_LegalStep> {
  final _cardKeys = <String, GlobalKey>{};

  OnboardingController get controller {
    OnboardingBinding.ensure();
    return Get.find<OnboardingController>();
  }

  GlobalKey _keyFor(String docKey) =>
      _cardKeys.putIfAbsent(docKey, GlobalKey.new);

  Future<void> _acceptAndScroll(LegalDocumentCurrent doc) async {
    await controller.acceptLegalDoc(doc);
    final nextKey = controller.nextIncompleteLegalDocKey;
    if (nextKey == null || !mounted) return;
    final ctx = _cardKeys[nextKey]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

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
          Text(
            'Accepted ${controller.legalAcceptedCount} of '
            '${controller.legalTotalCount}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review and accept each document separately.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final doc in controller.legalDocs) ...[
            KeyedSubtree(
              key: _keyFor(doc.docKey),
              child: _DocCard(
                title:
                    doc.docKey == 'platform_terms'
                        ? 'Platform Terms'
                        : 'Privacy Policy',
                markdown: doc.contentMd,
                counselPending: doc.counselPending,
                accepted: controller.acceptedDocKeys.contains(doc.docKey),
                isLoading: controller.isPending(
                  'accept-doc-${doc.docKey}-${doc.version}',
                ),
                onAccept: () => _acceptAndScroll(doc),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    });
  }
}

class _NoticesStep extends StatefulWidget {
  const _NoticesStep();

  @override
  State<_NoticesStep> createState() => _NoticesStepState();
}

class _NoticesStepState extends State<_NoticesStep> {
  final _cardKeys = <String, GlobalKey>{};

  OnboardingController get controller {
    OnboardingBinding.ensure();
    return Get.find<OnboardingController>();
  }

  GlobalKey _keyFor(String noticeKey) =>
      _cardKeys.putIfAbsent(noticeKey, GlobalKey.new);

  Future<void> _acknowledgeAndScroll(CollectionNotice notice) async {
    await controller.acknowledgeNotice(notice);
    final next = controller.nextIncompleteNotice;
    if (next == null || !mounted) return;
    final ctx = _cardKeys[next.noticeKey]?.currentContext;
    if (ctx != null) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
    }
  }

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
          Text(
            'Acknowledged ${controller.noticesAcknowledgedCount} of '
            '${controller.noticesTotalCount}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Acknowledge each collection notice separately.',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final n in controller.notices) ...[
            KeyedSubtree(
              key: _keyFor(n.noticeKey),
              child: _DocCard(
                title: n.noticeKey,
                markdown: n.contentMd,
                counselPending: n.counselPending,
                accepted: controller.acknowledgedNoticeKeys.contains(
                  n.noticeKey,
                ),
                isLoading: controller.isPending(
                  'ack-notice-${n.noticeKey}-${n.version}',
                ),
                acceptLabel: 'I acknowledge this notice',
                onAccept: () => _acknowledgeAndScroll(n),
              ),
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
  OnboardingController get controller {
    OnboardingBinding.ensure();
    return Get.find<OnboardingController>();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final needed =
          controller.notices
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
          Text(
            'Recorded ${controller.consentsRecordedCount} of '
            '${controller.consentsTotalCount}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sensitive credential types require an explicit consent '
            '(separate from Terms / Privacy).',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final type in needed) ...[
            Builder(
              builder: (context) {
                final isLoading = controller.isPending('consent-$type');
                return Card(
                  child: CheckboxListTile(
                    value: controller.consentedTypes.contains(type),
                    onChanged:
                        controller.consentedTypes.contains(type) || isLoading
                            ? null
                            : (_) => controller.consentToType(
                              type,
                              notice: noticeByType[type],
                            ),
                    secondary:
                        isLoading ? const ButtonLoadingIndicator() : null,
                    title: Text(type),
                    subtitle: Text(
                      noticeByType[type] != null
                          ? 'Linked notice: ${noticeByType[type]!.noticeKey}'
                          : 'Consent without linked notice key',
                    ),
                  ),
                );
              },
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
    required this.markdown,
    required this.counselPending,
    required this.accepted,
    required this.isLoading,
    required this.onAccept,
    this.acceptLabel = 'I accept this document',
  });

  final String title;
  final String markdown;
  final bool counselPending;
  final bool accepted;
  final bool isLoading;
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
              trailing: AsyncFilledButton(
                onPressed: onAccept,
                isLoading: isLoading,
                child: const Text('Accept'),
              ),
            ),
        ],
      ),
    );
  }
}
