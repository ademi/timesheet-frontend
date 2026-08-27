import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../controllers/clients_controller.dart';

/// Edit-only client form. New clients use [ClientOnboardingView].
class ClientFormView extends GetView<ClientsController> {
  const ClientFormView({super.key});

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Widget build(BuildContext context) {
    // Legacy create path → redirect to onboarding wizard.
    if (controller.isCreateFlow.value || controller.editing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Get.currentRoute == AppRoutes.staffClientForm) {
          Get.offNamed(AppRoutes.staffClientOnboarding);
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit client')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final progress = controller.profileSaveProgress.value;

        return Form(
          key: controller.clientFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    PageContent(
                      width: PageContentWidth.narrow,
                      child: _CoreDetailsStep(
                        controller: controller,
                        emailPattern: _emailPattern,
                        progress: progress,
                      ),
                    ),
                  ],
                ),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: FloatingErrorNotice(
                    message: err,
                    onDismiss: () => controller.errorMessage.value = null,
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: PageContent(
                    width: PageContentWidth.narrow,
                    child: AsyncElevatedButton(
                      onPressed: controller.saveClient,
                      isLoading: controller.isSaving.value,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Save client'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CoreDetailsStep extends StatelessWidget {
  const _CoreDetailsStep({
    required this.controller,
    required this.emailPattern,
    required this.progress,
  });

  final ClientsController controller;
  final RegExp emailPattern;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                            (controller.formPhoto.value?.hasPhoto ?? false)))
                    ? controller.clearFormPhoto
                    : null,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          Text(
            progress!,
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
          'Name plus email or phone are required. Set client type and '
          'documents on the Details tab after saving.',
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
            if (email.isNotEmpty && !emailPattern.hasMatch(email)) {
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
        ),
        const SizedBox(height: 12),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.status.value,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
            ],
            onChanged: (v) {
              if (v != null) controller.status.value = v;
            },
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.notesCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Service agreement notes',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
