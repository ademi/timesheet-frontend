import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/contractor_profile_controller.dart';
import '../data/models/compliance_ops_models.dart';

class ContractorProfileOpsView extends GetView<ContractorProfileController> {
  const ContractorProfileOpsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined),
              title: const Text('My payments'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(AppRoutes.contractorPayments),
            ),
            const Divider(height: 32),
            Text('Privacy rights', style: Get.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: controller.rightsType.value,
              items: [
                for (final t in rightsRequestTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) {
                if (v != null) controller.rightsType.value = v;
              },
              decoration: const InputDecoration(
                labelText: 'Request type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.rightsNotesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: controller.isSaving.value
                  ? null
                  : controller.submitRightsRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Submit rights request'),
            ),
            if (controller.lastRights.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Last: ${controller.lastRights.value!.requestType} · '
                  '${controller.lastRights.value!.status}',
                ),
              ),
            const Divider(height: 32),
            Text('Privacy export', style: Get.textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.isSaving.value
                  ? null
                  : controller.runPrivacyExport,
              child: const Text('Request privacy export'),
            ),
            if (controller.lastExport.value?.downloadUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(controller.lastExport.value!.downloadUrl!),
              ),
            const Divider(height: 32),
            Text('Withdraw consent', style: Get.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Explain effects before withdrawing. Provider may retain lawful copies.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.withdrawTypeCtrl,
              decoration: const InputDecoration(
                labelText: 'Credential type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.isSaving.value
                  ? null
                  : controller.confirmWithdrawConsent,
              child: const Text('Withdraw consent…'),
            ),
            const Divider(height: 32),
            Text('Recent alerts', style: Get.textTheme.titleMedium),
            if (controller.events.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('No notification events.'),
              ),
            for (final e in controller.events.take(10))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.summary),
                subtitle: Text(e.createdAt.toLocal().toString()),
              ),
          ],
        );
      }),
    );
  }
}
