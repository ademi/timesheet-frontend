import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/workforce_controller.dart';
import '../data/models/engagement_models.dart';

String _statusChipLabel(String status) => engagementStatusLabel(status);

class WorkforceListView extends GetView<WorkforceController> {
  const WorkforceListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workforce'),
        actions: shellAppBarActions(),
      ),
      floatingActionButton: !controller.canInvite
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Get.toNamed(AppRoutes.staffWorkforceInvite),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Invite'),
            ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: controller.statusFilter.value == null,
                              onSelected:
                                  (_) => controller.statusFilter.value = null,
                            ),
                          ),
                          for (final s in engagementStatuses)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(_statusChipLabel(s)),
                                selected: controller.statusFilter.value == s,
                                onSelected:
                                    (_) => controller.statusFilter.value = s,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Missing required docs'),
                                  if (controller.isLoadingCredentials.value) ...[
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              selected: controller.missingDocsFilter.value,
                              onSelected:
                                  controller.isLoadingCredentials.value
                                      ? null
                                      : (selected) => controller
                                          .setMissingDocsFilter(selected),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (err != null) ...[
                      Material(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(8),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
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
                    for (final e in controller.filtered)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Obx(() {
                            final photo =
                                controller.photosByContractor[e.contractorId];
                            return ProfilePhotoEditor(
                              networkUrl: photo?.downloadUrl,
                              documentId: photo?.documentId,
                              readOnly: true,
                              size: 48,
                              showLabel: false,
                            );
                          }),
                          title: Text(e.displayName),
                          subtitle: Text('Status: ${e.statusLabel}'),
                          trailing: _StatusChip(status: e.status),
                          onTap: () => controller.openDetail(e),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => AppColors.success,
      'suspended' || 'ended' => AppColors.error,
      'approved' => AppColors.primary,
      _ => AppColors.slate600,
    };
    return Chip(
      label: Text(
        engagementStatusLabel(status),
        style: TextStyle(color: color, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
