import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/staff_tenant_settings_controller.dart';

class StaffTenantSettingsView extends GetView<StaffTenantSettingsController> {
  const StaffTenantSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.tenant.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(err, style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              controller.tenant.value?.name ?? 'Tenant',
              style: Get.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Timezone and public holiday jurisdiction are used for rate bands '
              'and recurrence display. Fields appear when the API exposes them.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            if (controller.canManage)
              ElevatedButton(
                onPressed: controller.isSaving.value ? null : controller.save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Save'),
              )
            else
              const Text(
                'Read-only — needs tenants.manage to edit.',
                style: TextStyle(fontSize: 12),
              ),
          ],
        );
      }),
    );
  }
}
