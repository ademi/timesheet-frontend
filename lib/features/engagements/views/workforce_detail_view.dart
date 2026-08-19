import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/eligibility_incomplete_panel.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../../shared/widgets/subject_tab_bar.dart';
import '../../payroll/widgets/engagement_rate_bands_section.dart';
import '../controllers/workforce_controller.dart';
import '../data/models/engagement_models.dart';

class WorkforceDetailView extends GetView<WorkforceController> {
  const WorkforceDetailView({super.key});

  static const _tabLabels = [
    'Overview',
    'Credentials',
    'Visits',
    'Schedule',
  ];

  @override
  Widget build(BuildContext context) {
    final arg = Get.arguments;
    final EngagementOut? initial =
        arg is EngagementOut ? arg : controller.selected;
    if (initial == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Engagement')),
        body: const Center(child: Text('Engagement not found.')),
      );
    }

    return Obx(() {
      EngagementOut current = initial;
      for (final e in controller.items) {
        if (e.id == initial.id) {
          current = e;
          break;
        }
      }
      if (controller.selected?.id == initial.id) {
        current = controller.selected!;
      }
      final err = controller.errorMessage.value;
      final tab = controller.tabIndex.value;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(current.displayName),
        ),
        body: Column(
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      err,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    trailing: IconButton(
                      tooltip: 'Dismiss',
                      onPressed: controller.clearError,
                      icon: const Icon(Icons.close, color: AppColors.error),
                    ),
                  ),
                ),
              ),
            if (controller.eligibilityReasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: EligibilityIncompletePanel(
                  reasons: controller.eligibilityReasons.toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  ProfilePhotoEditor(
                    networkUrl: controller.detailPhoto.value?.downloadUrl,
                    documentId: controller.detailPhoto.value?.documentId,
                    isLoading: controller.isDetailPhotoLoading.value,
                    readOnly: true,
                    size: 72,
                    showLabel: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    current.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SubjectTabBar(
              labels: _tabLabels,
              index: tab,
              keyPrefix: 'contractor-detail-tab',
              onChanged: (i) => controller.tabIndex.value = i,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  PageContent(
                    width: PageContentWidth.wide,
                    child: _tabContent(current, tab),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _tabContent(EngagementOut current, int tab) {
    switch (tab) {
      case WorkforceController.tabCredentials:
        return _credentialsContent(current);
      case WorkforceController.tabVisits:
      case WorkforceController.tabSchedule:
        return const SizedBox.shrink();
      case WorkforceController.tabOverview:
      default:
        return _overviewContent(current);
    }
  }

  Widget _credentialsContent(EngagementOut current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Review submitted certificates. Required document types are edited on the review screen.',
        ),
        if (!current.isEnded) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => controller.openCredentialReview(current),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Review credentials'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _overviewContent(EngagementOut current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Status', current.statusLabel),
        const SizedBox(height: 16),
        const Text(
          'Lifecycle',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _lifecycleSection(current),
        const SizedBox(height: 24),
        const Text(
          'Payment rates',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        EngagementRateBandsSection(
          key: ValueKey(current.id),
          engagementId: current.id,
          canEditRates: !current.isEnded,
        ),
      ],
    );
  }

  Widget _lifecycleSection(EngagementOut current) {
    if (!controller.canApprove && !controller.canManage) {
      return const Text(
        'No lifecycle actions available for your role.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }

    if (current.isInvited) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Waiting for the contractor to accept the invite.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          if (controller.canManage) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.isSaving.value
                  ? null
                  : () => controller.runAction('withdraw', current),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Withdraw invite'),
            ),
          ],
        ],
      );
    }

    final actions = <Widget>[
      if (controller.canApprove && current.isPendingDocs) ...[
        _actionButton(
          label: 'Approve',
          onPressed: () => controller.runAction('approve', current),
        ),
        _actionButton(
          label: 'Approve & activate',
          onPressed: () => controller.runAction('approve_and_activate', current),
        ),
      ],
      if (controller.canManage && current.isApproved)
        _actionButton(
          label: 'Activate',
          onPressed: () => controller.runAction('activate', current),
        ),
      if (controller.canManage && current.isActive)
        _actionButton(
          label: 'Suspend',
          onPressed: () => controller.runAction('suspend', current),
        ),
      if (controller.canManage && current.isSuspended)
        _actionButton(
          label: 'Resume',
          onPressed: () => controller.runAction('resume', current),
        ),
      if (controller.canManage && !current.isEnded && !current.isInvited)
        OutlinedButton(
          onPressed: controller.isSaving.value
              ? null
              : () => controller.runAction('end', current),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('End engagement'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return AsyncElevatedButton(
      onPressed: onPressed,
      isLoading: controller.isSaving.value,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(label),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
