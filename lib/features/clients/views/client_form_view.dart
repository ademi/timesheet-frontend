import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_requirement_editors.dart';

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
        final types = controller.clientTypes;
        final selectedTypeId = controller.selectedClientTypeId.value;
        final drafts = controller.requirementDrafts;

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
            if (progress != null) ...[
              Text(
                progress,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            const Text(
              'Core details',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
            const Text(
              'Client type',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a type to show optional profile requirements.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (controller.isLoadingTypes.value)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (types.isEmpty)
              const Text(
                'No client types available. You can still save core details.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              DropdownButtonFormField<String>(
                value: selectedTypeId != null &&
                        types.any((t) => t.id == selectedTypeId)
                    ? selectedTypeId
                    : null,
                items: [
                  for (final t in types)
                    DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name),
                    ),
                ],
                onChanged: controller.isSaving.value
                    ? null
                    : (v) => controller.onClientTypeChanged(v),
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
              ),
            if (controller.isLoadingRequirements.value) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (drafts.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Type-specific details',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'All items are optional unless marked required.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              for (final draft in drafts)
                ClientRequirementEditor(
                  controller: controller,
                  draft: draft,
                ),
            ],
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
