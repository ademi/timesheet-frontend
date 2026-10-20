import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/staff_detail_controller.dart';
import '../data/staff_preset_catalog.dart';
import '../widgets/staff_preset_info_sheet.dart';

class StaffDetailView extends GetView<StaffDetailController> {
  const StaffDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Staff detail')),
      body: Obx(() {
        if (controller.isLoading.value && controller.member.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final m = controller.member.value;
        final err = controller.errorMessage.value;
        if (m == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(err ?? 'Staff member not found.'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    m.fullName ?? m.email,
                    style: Get.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(m.email, style: const TextStyle(color: AppColors.textMuted)),
                  if (m.phone != null && m.phone!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      m.phone!,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                  if (controller.isSelf) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'This is your account. You can’t change your own '
                        'job title or active status.',
                      ),
                    ),
                  ],
                  if (err != null) ...[
                    const SizedBox(height: 12),
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
                          onPressed:
                              () => controller.errorMessage.value = null,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: Text(
                      controller.isActive.value
                          ? 'Can sign in to this organisation'
                          : 'Cannot sign in until reactivated',
                    ),
                    value: controller.isActive.value,
                    onChanged:
                        controller.canEditRoleAndStatus
                            ? controller.setActive
                            : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Job title',
                    style: Get.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap (i) to see what each title can and cannot do.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (controller.isLoadingRoles.value &&
                      controller.pickerRoles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    ...controller.pickerRoles.map((role) {
                      final selected =
                          controller.selectedPresetKey.value == role.key;
                      final label = staffPresetDisplayName(
                        role.key,
                        fallback: role.displayName,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color:
                                selected
                                    ? AppColors.primary
                                    : AppColors.textMuted.withValues(
                                      alpha: 0.35,
                                    ),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap:
                              controller.canEditRoleAndStatus
                                  ? () => controller.selectPreset(role.key)
                                  : null,
                          leading: Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color:
                                selected
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                          ),
                          title: Text(label),
                          trailing: IconButton(
                            tooltip: 'What can $label do?',
                            icon: const Icon(Icons.info_outline),
                            onPressed:
                                () => showStaffPresetInfoSheet(
                                  context,
                                  presetKey: role.key,
                                  displayName: label,
                                ),
                          ),
                        ),
                      );
                    }),
                  if (!controller.canAssignAdmin) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Admin job title is only available to owners.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (controller.canEditRoleAndStatus)
                    AsyncElevatedButton(
                      onPressed: controller.save,
                      isLoading: controller.isSaving.value,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cta,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Save changes'),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
