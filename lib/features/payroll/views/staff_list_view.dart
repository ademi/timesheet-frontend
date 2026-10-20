import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../../app/constants/app_permissions.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/staff_list_controller.dart';
import '../data/staff_preset_catalog.dart';

class StaffListView extends GetView<StaffListController> {
  const StaffListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Staff'),
        actions: shellAppBarActions(),
      ),
      floatingActionButton: PermissionGate(
        permission: AppPermissions.tenantMembersManage,
        child: FloatingActionButton.extended(
          onPressed: controller.openAdd,
          backgroundColor: AppColors.cta,
          foregroundColor: AppColors.onCta,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add staff'),
        ),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.members.isEmpty) {
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
                    const Text(
                      'People with access to this organisation.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
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
                    const SizedBox(height: 12),
                    if (controller.members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No staff yet.'),
                      ),
                    for (final m in controller.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap:
                            controller.canManageStaff
                                ? () => controller.openDetail(m)
                                : null,
                        title: Text(m.fullName ?? m.email),
                        subtitle: Text(m.email),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Chip(
                                  label: Text(
                                    staffPresetDisplayName(
                                      m.roleKey ?? '',
                                      fallback: m.roleLabel,
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                ),
                                Chip(
                                  label: Text(
                                    m.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          m.isActive
                                              ? AppColors.success
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.zero,
                                  backgroundColor:
                                      m.isActive
                                          ? AppColors.successBackground
                                          : AppColors.slate200,
                                ),
                              ],
                            ),
                            if (controller.canManageStaff)
                              const Icon(Icons.chevron_right),
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
