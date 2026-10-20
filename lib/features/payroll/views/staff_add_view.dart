import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/staff_add_controller.dart';
import '../data/staff_preset_catalog.dart';
import '../widgets/staff_preset_info_sheet.dart';

class StaffAddView extends GetView<StaffAddController> {
  const StaffAddView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add staff')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Invite a staff member by email. They receive a magic '
                      'link and set their own password.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
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
                            onPressed: () => controller.errorMessage.value = null,
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: controller.fullNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        border: OutlineInputBorder(),
                      ),
                      validator: controller.validateFullName,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller.emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: controller.validateEmail,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller.phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                            onTap: () => controller.selectPreset(role.key),
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
                    AsyncElevatedButton(
                      onPressed: controller.submit,
                      isLoading: controller.isSaving.value,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cta,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Send invite'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
