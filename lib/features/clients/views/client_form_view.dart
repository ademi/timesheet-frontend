import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_detail_contacts_section.dart';
import '../widgets/client_detail_sites_section.dart';
import '../widgets/client_requirement_editors.dart';

class ClientFormView extends GetView<ClientsController> {
  const ClientFormView({super.key});

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editing != null && !controller.isCreateFlow.value;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit client' : 'New client')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final progress = controller.profileSaveProgress.value;

        return Form(
          key: controller.clientFormKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: controller.isCreateFlow.value
              ? Stepper(
                  currentStep: controller.createStepIndex.value,
                  onStepContinue: controller.isSaving.value
                      ? null
                      : () {
                          if (controller.createStepIndex.value == 3) {
                            controller.finishCreateFlow();
                          } else {
                            controller.continueCreateFlow();
                          }
                        },
                  onStepCancel: controller.createStepIndex.value == 0 ||
                          controller.isSaving.value
                      ? null
                      : controller.backCreateFlow,
                  controlsBuilder: (context, details) {
                    final isLast = controller.createStepIndex.value == 3;
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: AsyncElevatedButton(
                              onPressed: details.onStepContinue,
                              isLoading: controller.isSaving.value,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: Text(
                                isLast ? 'Finish client setup' : 'Save & continue',
                              ),
                            ),
                          ),
                          if (controller.createStepIndex.value > 0) ...[
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: details.onStepCancel,
                              child: const Text('Back'),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Client'),
                      isActive: controller.createStepIndex.value >= 0,
                      content: _CoreDetailsStep(
                        controller: controller,
                        emailPattern: _emailPattern,
                        error: err,
                        progress: progress,
                      ),
                    ),
                    Step(
                      title: const Text('Sites'),
                      isActive: controller.createStepIndex.value >= 1,
                      content: _CreateSitesStep(controller: controller),
                    ),
                    Step(
                      title: const Text('Contacts'),
                      isActive: controller.createStepIndex.value >= 2,
                      content: _CreateContactsStep(controller: controller),
                    ),
                    Step(
                      title: const Text('Documents'),
                      isActive: controller.createStepIndex.value >= 3,
                      content: _CreateDetailsStep(
                        controller: controller,
                        progress: progress,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _CoreDetailsStep(
                      controller: controller,
                      emailPattern: _emailPattern,
                      error: err,
                      progress: progress,
                      showHelperCopy: true,
                      showServiceAgreement: true,
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
                      child: const Text('Save client'),
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
    required this.error,
    required this.progress,
    this.showHelperCopy = false,
    this.showServiceAgreement = false,
  });

  final ClientsController controller;
  final RegExp emailPattern;
  final String? error;
  final String? progress;
  final bool showHelperCopy;
  final bool showServiceAgreement;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Center(
          child: ProfilePhotoEditor(
            localBytes: controller.formLocalPhotoBytes.value,
            networkUrl: controller.formPhotoCleared.value
                ? null
                : controller.formPhoto.value?.downloadUrl,
            documentId: controller.formPhotoCleared.value
                ? null
                : controller.formPhoto.value?.documentId,
            isLoading:
                controller.isFormPhotoLoading.value || controller.isSaving.value,
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
        Text(
          showHelperCopy
              ? 'Name plus email or phone are required. Set client type and '
                  'documents on the Details tab after saving.'
              : 'Start with the basics. Client type is set to Patient during '
                  'creation, and the remaining steps cover sites, contacts, '
                  'documents, and profile details.',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
        if (showServiceAgreement) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Service agreement notes',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}

class _CreateSitesStep extends StatelessWidget {
  const _CreateSitesStep({required this.controller});

  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add any sites now, or continue and come back later from the client record.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        ClientDetailSitesSection(
          sites: controller.sites.toList(),
          canManage: controller.canManage,
          onAdd: () => controller.beginSiteForm(),
          onEdit: (site) => controller.beginSiteForm(site: site),
          onDelete: controller.deleteSite,
        ),
      ],
    );
  }
}

class _CreateContactsStep extends StatelessWidget {
  const _CreateContactsStep({required this.controller});

  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add client contacts in this step if staff already know them.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        ClientDetailContactsSection(
          contacts: controller.contacts.toList(),
          canManage: controller.canManage,
          onAdd: () => controller.beginContactForm(),
          onEdit: (contact) => controller.beginContactForm(contact: contact),
          onDelete: controller.deleteContact,
        ),
      ],
    );
  }
}

class _CreateDetailsStep extends StatelessWidget {
  const _CreateDetailsStep({
    required this.controller,
    required this.progress,
  });

  final ClientsController controller;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Patient details and required documents',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Client type is set to Patient automatically for now. Add any type-specific '
          'details and documents here before finishing.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        if (progress != null) ...[
          const SizedBox(height: 12),
          Text(
            progress!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (controller.isLoadingRequirements.value) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 2),
        ] else if (controller.requirementDrafts.isEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'No additional patient requirements are configured.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ] else ...[
          const SizedBox(height: 16),
          for (final draft in controller.requirementDrafts)
            ClientRequirementEditor(
              controller: controller,
              draft: draft,
            ),
        ],
      ],
    );
  }
}
