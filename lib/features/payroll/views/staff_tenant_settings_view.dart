import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/max_width_box.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/staff_tenant_settings_controller.dart';

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
        return MaxWidthBox(
          maxWidth: Breakpoints.narrowContent,
          child: ListView(
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
                        'Subscription: ${sub.status}'
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
              onTap: () => Get.toNamed(AppRoutes.staffJobs),
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
            const SizedBox(height: 16),
            if (controller.canManage)
              AsyncElevatedButton(
                onPressed: controller.save,
                isLoading: controller.isSaving.value,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Save'),
              ),
            if (controller.canViewMembers) ...[
              const Divider(height: 32),
              Text('Members', style: Get.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (controller.members.isEmpty) const Text('No members loaded.'),
              for (final m in controller.members)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.fullName ?? m.email),
                  subtitle: Text(
                    '${m.email}${m.role != null ? ' · ${m.role}' : ''}',
                  ),
                ),
            ],
          ],
        ),
        );
      }),
    );
  }
}
