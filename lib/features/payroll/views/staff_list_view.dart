import 'package:flutter/gestures.dart';
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
        final visible = controller.filtered;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PageContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Team members with login access to this organisation. '
                        'Use the tabs to filter by job title.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StaffRoleFilters(controller: controller),
                    ],
                  ),
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
                            const SizedBox(height: 12),
                          ],
                          if (visible.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Text(
                                controller.roleFilter.value == null
                                    ? 'No staff yet.'
                                    : 'No staff match this job title.',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          for (final m in visible)
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
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
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
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StaffRoleFilters extends StatefulWidget {
  const _StaffRoleFilters({required this.controller});

  final StaffListController controller;

  @override
  State<_StaffRoleFilters> createState() => _StaffRoleFiltersState();
}

class _StaffRoleFiltersState extends State<_StaffRoleFilters> {
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
          child: Obx(() {
            final roles = controller.availableRoleKeys;
            return Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: controller.roleFilter.value == null,
                    onSelected: (_) => controller.roleFilter.value = null,
                  ),
                ),
                for (final key in roles)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(controller.roleTabLabel(key)),
                      selected: controller.roleFilter.value == key,
                      onSelected: (_) => controller.roleFilter.value = key,
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            );
          }),
        ),
      ),
    );
  }
}
