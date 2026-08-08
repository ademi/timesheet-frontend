import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../controllers/clients_controller.dart';

class ClientFormView extends GetView<ClientsController> {
  const ClientFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit client' : 'New client')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final progress = controller.profileSaveProgress.value;

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
            Center(
              child: ProfilePhotoEditor(
                localBytes: controller.formLocalPhotoBytes.value,
                networkUrl: controller.formPhotoCleared.value
                    ? null
                    : controller.formPhoto.value?.downloadUrl,
                isLoading: controller.isFormPhotoLoading.value ||
                    controller.isSaving.value,
                enabled: controller.canUploadDocs || controller.canManage,
                onChanged: controller.onFormPhotoPicked,
                onRemove: (controller.formPendingPhoto.value != null ||
                        (!controller.formPhotoCleared.value &&
                            (controller.formPhoto.value?.hasPhoto ?? false)))
                    ? controller.clearFormPhoto
                    : null,
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              Text(
                progress,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Core details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set client type and documents on the Types tab after saving.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: controller.status.value,
              items: const [
                DropdownMenuItem(value: 'active', child: Text('active')),
                DropdownMenuItem(value: 'inactive', child: Text('inactive')),
              ],
              onChanged: (v) {
                if (v != null) controller.status.value = v;
              },
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Service agreement notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            AsyncElevatedButton(
              onPressed: controller.saveClient,
              isLoading: controller.isSaving.value,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(isEdit ? 'Save client' : 'Save client'),
            ),
          ],
        );
      }),
    );
  }
}
