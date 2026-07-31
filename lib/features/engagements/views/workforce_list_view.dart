import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/workforce_controller.dart';
import '../data/models/engagement_models.dart';

String _statusChipLabel(String status) => status.replaceAll('_', ' ');

class WorkforceListView extends GetView<WorkforceController> {
  const WorkforceListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Workforce'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
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
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      onSelected:
                          controller.isLoadingCredentials.value
                              ? null
                              : (selected) =>
                                  controller.setMissingDocsFilter(selected),
                    ),
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(err, style: const TextStyle(color: AppColors.error)),
                ),
              ),
            Expanded(
              child: controller.isLoading.value && controller.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: controller.filtered.length,
                        itemBuilder: (context, index) {
                          final e = controller.filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(
                                e.contractorName?.isNotEmpty == true
                                    ? e.contractorName!
                                    : e.contractorId,
                              ),
                              subtitle: Text(
                                'Status: ${e.status}\n'
                                'Required: ${e.requiredDocCategories.map((c) => c.category).join(", ").ifEmpty("—")}',
                              ),
                              isThreeLine: true,
                              trailing: _StatusChip(status: e.status),
                              onTap: () => controller.openDetail(e),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
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
      label: Text(status, style: TextStyle(color: color, fontSize: 11)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
