import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../controllers/clients_controller.dart';

class ClientFormView extends GetView<ClientsController> {
  const ClientFormView({super.key});

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editing != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit client' : 'New client')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final progress = controller.profileSaveProgress.value;

        return Form(
          key: controller.clientFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  child: Text(
                    err,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Center(
                child: ProfilePhotoEditor(
                  localBytes: controller.formLocalPhotoBytes.value,
                  networkUrl:
                      controller.formPhotoCleared.value
                          ? null
                          : controller.formPhoto.value?.downloadUrl,
                  documentId:
                      controller.formPhotoCleared.value
                          ? null
                          : controller.formPhoto.value?.documentId,
                  isLoading:
                      controller.isFormPhotoLoading.value ||
                      controller.isSaving.value,
                  enabled: controller.canUploadDocs || controller.canManage,
                  onChanged: controller.onFormPhotoPicked,
                  onRemove:
                      (controller.formPendingPhoto.value != null ||
                              (!controller.formPhotoCleared.value &&
                                  (controller.formPhoto.value?.hasPhoto ??
                                      false)))
                          ? controller.clearFormPhoto
                          : null,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 8),
                Text(
                  progress,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Core details',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Name plus email or phone are required. Set client type and '
                'documents on the Types tab after saving.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Full name is required.';
                  if (name.length < 2) {
                    return 'Enter at least 2 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(),
                  helperText: 'Email or phone is required',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  final phone = controller.phoneCtrl.text.trim();
                  if (email.isEmpty && phone.isEmpty) {
                    return 'Provide an email or a phone number.';
                  }
                  if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  border: OutlineInputBorder(),
                  helperText: 'Email or phone is required',
                ),
                validator: (value) {
                  final phone = value?.trim() ?? '';
                  final email = controller.emailCtrl.text.trim();
                  if (email.isEmpty && phone.isEmpty) {
                    return 'Provide an email or a phone number.';
                  }
                  if (phone.isNotEmpty && phone.length < 6) {
                    return 'Enter a valid phone number.';
                  }
                  return null;
                },
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
              TextFormField(
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
          ),
        );
      }),
    );
  }
}
