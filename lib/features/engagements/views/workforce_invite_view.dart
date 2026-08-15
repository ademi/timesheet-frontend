import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/workforce_controller.dart';

class WorkforceInviteView extends StatefulWidget {
  const WorkforceInviteView({super.key});

  @override
  State<WorkforceInviteView> createState() => _WorkforceInviteViewState();
}

class _WorkforceInviteViewState extends State<WorkforceInviteView> {
  late final WorkforceController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<WorkforceController>();
    controller.clearError();
    controller.loadCredentialCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Invite contractor')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Invite by email and/or phone. Select at least one required '
              'document type.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            if (err != null) ...[
              const SizedBox(height: 12),
              Material(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    err,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  trailing: IconButton(
                    tooltip: 'Dismiss',
                    onPressed: controller.clearError,
                    icon: const Icon(Icons.close, color: AppColors.error),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: controller.emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Required documents',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (controller.isLoadingCatalog.value &&
                controller.catalogCategories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cat in controller.inviteCategoryChoices)
                    FilterChip(
                      label: Text(cat.label),
                      selected: controller.selectedCategories.contains(
                        cat.code,
                      ),
                      onSelected: (_) => controller.toggleCategory(cat.code),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  controller.isSaving.value ? null : controller.submitInvite,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child:
                  controller.isSaving.value
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Send invite'),
            ),
          ],
        );
      }),
    );
  }
}
