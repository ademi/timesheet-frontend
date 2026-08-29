import 'package:flutter/gestures.dart';
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
      floatingActionButton: (!controller.canInvite && !controller.canManage)
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (controller.canManage)
                  FloatingActionButton.extended(
                    heroTag: 'workforce-add',
                    onPressed: () =>
                        Get.toNamed(AppRoutes.staffWorkforceOnboarding),
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add contractor'),
                  ),
                if (controller.canManage && controller.canInvite)
                  const SizedBox(height: 12),
                if (controller.canInvite)
                  FloatingActionButton.extended(
                    heroTag: 'workforce-invite',
                    onPressed: () =>
                        Get.toNamed(AppRoutes.staffWorkforceInvite),
                    backgroundColor: controller.canManage
                        ? AppColors.surface
                        : AppColors.primary,
                    foregroundColor: controller.canManage
                        ? AppColors.primary
                        : AppColors.onPrimary,
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Invite'),
                  ),
              ],
            ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value &&
            controller.items.isEmpty &&
            controller.pendingInvites.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = controller.filteredPendingInvites;
        final engagements = controller.filtered;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PageContent(
                  child: _WorkforceStatusFilters(controller: controller),
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    PageContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                  icon: const Icon(
                                    Icons.close,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          for (final invite in pending)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.slate600.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: const Icon(
                                    Icons.mail_outline,
                                    color: AppColors.slate600,
                                  ),
                                ),
                                title: Text(invite.email),
                                subtitle: Text(
                                  'Status: Invited · Expires ${invite.expiresAt.toLocal()}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (controller.canInvite)
                                      _ReEmailButton(
                                        busy:
                                            controller.resendingInviteId.value ==
                                            invite.id,
                                        onPressed: () => controller
                                            .resendPendingInvite(invite),
                                      ),
                                    const SizedBox(width: 8),
                                    const _StatusChip(status: 'invited'),
                                  ],
                                ),
                              ),
                            ),
                          for (final e in engagements)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Obx(() {
                                  final photo = controller
                                      .photosByContractor[e.contractorId];
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
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (controller.canInvite && e.isInvited) ...[
                                      _ReEmailButton(
                                        busy:
                                            controller.resendingInviteId.value ==
                                            e.id,
                                        onPressed: () => controller
                                            .resendEngagementInviteEmail(e),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    _StatusChip(status: e.status),
                                  ],
                                ),
                                onTap: () => controller.openDetail(e),
                              ),
                            ),
                          if (pending.isEmpty && engagements.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48),
                              child: Center(
                                child: Column(
                                  children: [
                                    Text(
                                      controller.statusFilter.value == null &&
                                              !controller.missingDocsFilter.value
                                          ? 'No contractors yet.'
                                          : 'No contractors match this filter.',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    if (controller.statusFilter.value == null &&
                                        !controller.missingDocsFilter.value &&
                                        (controller.canManage ||
                                            controller.canInvite)) ...[
                                      const SizedBox(height: 16),
                                      if (controller.canManage)
                                        TextButton.icon(
                                          onPressed: () => Get.toNamed(
                                            AppRoutes.staffWorkforceOnboarding,
                                          ),
                                          icon: const Icon(Icons.person_add),
                                          label: const Text('Add contractor'),
                                        ),
                                      if (controller.canInvite)
                                        TextButton.icon(
                                          onPressed: () => Get.toNamed(
                                            AppRoutes.staffWorkforceInvite,
                                          ),
                                          icon: const Icon(Icons.mail_outline),
                                          label: const Text('Invite contractor'),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
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

class _WorkforceStatusFilters extends StatefulWidget {
  const _WorkforceStatusFilters({required this.controller});

  final WorkforceController controller;

  @override
  State<_WorkforceStatusFilters> createState() => _WorkforceStatusFiltersState();
}

class _WorkforceStatusFiltersState extends State<_WorkforceStatusFilters> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: controller.statusFilter.value == null,
                  onSelected: (_) => controller.statusFilter.value = null,
                ),
              ),
              for (final s in engagementStatuses)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_statusChipLabel(s)),
                    selected: controller.statusFilter.value == s,
                    onSelected: (_) => controller.statusFilter.value = s,
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
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  selected: controller.missingDocsFilter.value,
                  onSelected: controller.isLoadingCredentials.value
                      ? null
                      : (selected) =>
                          controller.setMissingDocsFilter(selected),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReEmailButton extends StatelessWidget {
  const _ReEmailButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: onPressed,
      child: const Text('Re-email'),
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
      'awaiting_approval' => const Color(0xFFCA8A04),
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
