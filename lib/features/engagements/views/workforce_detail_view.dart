import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/eligibility_incomplete_panel.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../payroll/widgets/engagement_rate_bands_section.dart';
import '../controllers/workforce_controller.dart';
import '../data/models/engagement_models.dart';

class WorkforceDetailView extends GetView<WorkforceController> {
  const WorkforceDetailView({super.key});

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

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(current.displayName),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[
              Material(
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
              const SizedBox(height: 12),
            ],
            if (controller.eligibilityReasons.isNotEmpty) ...[
              EligibilityIncompletePanel(
                reasons: controller.eligibilityReasons.toList(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                ProfilePhotoEditor(
                  networkUrl: controller.detailPhoto.value?.downloadUrl,
                  documentId: controller.detailPhoto.value?.documentId,
                  isLoading: controller.isDetailPhotoLoading.value,
                  readOnly: true,
                  size: 72,
                  showLabel: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    current.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _row('Status', current.statusLabel),
            _row(
              'Required documents',
              current.requiredDocCategories.isEmpty
                  ? '—'
                  : current.requiredDocCategories
                      .map((c) => c.displayLabel)
                      .join(', '),
            ),
            const SizedBox(height: 16),
            const Text(
              'Lifecycle',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (!controller.canApprove && !controller.canManage)
              const Text(
                'No lifecycle actions available for your role.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else if (current.isInvited)
              const Text(
                'Waiting for the contractor to accept the invite.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (controller.canApprove && current.isPendingDocs) ...[
                    _actionButton(
                      label: 'Approve',
                      onPressed: () => controller.runAction('approve', current),
                    ),
                    _actionButton(
                      label: 'Approve & activate',
                      onPressed:
                          () => controller.runAction(
                            'approve_and_activate',
                            current,
                          ),
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
                  if (controller.canManage &&
                      !current.isEnded &&
                      !current.isInvited)
                    OutlinedButton(
                      onPressed:
                          controller.isSaving.value
                              ? null
                              : () => controller.runAction('end', current),
                      child: const Text('End engagement'),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            const Text(
              'Credentials',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => controller.openCredentialReview(current),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Review credentials'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment rates',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            EngagementRateBandsSection(
              key: ValueKey(current.id),
              engagementId: current.id,
            ),
          ],
        ),
      );
    });
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
