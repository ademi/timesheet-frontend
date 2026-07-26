import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../credentials/data/models/credential_models.dart';
import '../controllers/workforce_controller.dart';
import '../data/models/engagement_models.dart';

class WorkforceInviteView extends GetView<WorkforceController> {
  const WorkforceInviteView({super.key});

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
              'Invite by email and/or phone. At least one required credential '
              'category must be selected from the allowlist.',
              style: TextStyle(color: AppColors.textMuted),
            ),
            if (err != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(err, style: const TextStyle(color: AppColors.error)),
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
              'Required categories',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in inviteCategoryOptions)
                  FilterChip(
                    label: Text(credentialTypeLabel(cat)),
                    selected: controller.selectedCategories.contains(cat),
                    onSelected: (_) => controller.toggleCategory(cat),
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
              child: controller.isSaving.value
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
