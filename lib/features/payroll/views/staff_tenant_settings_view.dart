import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/humanize_label.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/staff_tenant_settings_controller.dart';
import '../data/staff_preset_catalog.dart';

class StaffTenantSettingsView extends GetView<StaffTenantSettingsController> {
  const StaffTenantSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.tenant.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final sub = controller.subscription.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
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
                  Text(
                    controller.tenant.value?.name ?? 'Tenant',
                    style: Get.textTheme.titleMedium,
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Subscription: ${humanizeLabel(sub.status)}'
                              '${sub.planName != null ? ' · ${sub.planName}' : ''}',
                            ),
                          ),
                          TextButton(
                            onPressed: controller.openBilling,
                            child: const Text('Billing'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.work_outline),
                    title: const Text('Supports'),
                    subtitle: const Text('Advanced list of ongoing support'),
                    onTap: () => AppNavigator.push(AppRoutes.staffJobs),
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Timezone and public holiday jurisdiction (when API exposes them).',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.timezoneCtrl,
                    enabled: controller.canManage,
                    decoration: const InputDecoration(
                      labelText: 'Timezone (e.g. Australia/Sydney)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.jurisdictionCtrl,
                    enabled: controller.canManage,
                    decoration: const InputDecoration(
                      labelText: 'Public holiday jurisdiction',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller.providerAbnCtrl,
                    enabled: controller.canManage,
                    decoration: const InputDecoration(
                      labelText: 'Provider ABN (11 digits)',
                      helperText:
                          'Required before plan-managed claim exports. '
                          '11 digits, ABR checksum.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Unregistered providers use 90% of catalogue price limits '
                    'from 1 Jan 2027 (snapshotted at publish).',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: controller.ndisProviderRegistrationStatus.value,
                    decoration: const InputDecoration(
                      labelText: 'NDIS provider registration',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'registered',
                        child: Text('Registered'),
                      ),
                      DropdownMenuItem(
                        value: 'unregistered',
                        child: Text('Unregistered (−10% from 2027)'),
                      ),
                    ],
                    onChanged:
                        controller.canManage
                            ? (v) {
                              if (v != null) {
                                controller
                                    .ndisProviderRegistrationStatus
                                    .value = v;
                              }
                            }
                            : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Default progress-note template for visits when a client '
                    'has no form defaults of their own.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    key: const Key('tenant-default-progress-note'),
                    value: () {
                      final id = controller.defaultProgressNoteTemplateId.value;
                      final ids = {
                        for (final t in controller.formTemplates) t.id,
                      };
                      return id != null && ids.contains(id) ? id : null;
                    }(),
                    decoration: const InputDecoration(
                      labelText: 'Org default progress note',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      for (final t in controller.formTemplates)
                        DropdownMenuItem<String?>(
                          value: t.id,
                          child: Text(t.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged:
                        controller.canManage
                            ? (v) =>
                                controller.defaultProgressNoteTemplateId.value =
                                    v
                            : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'When a visit uses enforce geofence: soft allows the punch '
                    'and opens a variance for review; hard blocks with '
                    'geofence_rejected.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: controller.geofenceOutsidePolicy.value,
                    decoration: const InputDecoration(
                      labelText: 'Outside geofence policy',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'soft',
                        child: Text('Soft (allow + variance)'),
                      ),
                      DropdownMenuItem(
                        value: 'hard',
                        child: Text('Hard (reject punch)'),
                      ),
                    ],
                    onChanged:
                        controller.canManage
                            ? (v) {
                              if (v != null) {
                                controller.geofenceOutsidePolicy.value = v;
                              }
                            }
                            : null,
                  ),
                  const SizedBox(height: 16),
                  if (controller.canManage)
                    AsyncElevatedButton(
                      onPressed: controller.save,
                      isLoading: controller.isSaving.value,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cta,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Save'),
                    ),
                  if (controller.canViewMembers) ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Staff',
                            style: Get.textTheme.titleMedium,
                          ),
                        ),
                        PermissionGate(
                          permission: AppPermissions.tenantMembersManage,
                          child: TextButton.icon(
                            onPressed:
                                () => AppNavigator.push(AppRoutes.staffAdd),
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('Add staff'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'People with access to this organisation.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (controller.members.isEmpty)
                      const Text('No staff loaded.'),
                    for (final m in controller.members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap:
                            controller.canManageStaff
                                ? () => AppNavigator.push(
                                  AppNavigator.location(
                                    AppRoutes.staffDetail,
                                    query: {'id': m.id},
                                  ),
                                  extra: m,
                                )
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
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
