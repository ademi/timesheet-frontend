import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/clients_controller.dart';
import 'client_requirement_editors.dart';

class ClientDetailProfileSection extends StatelessWidget {
  const ClientDetailProfileSection({super.key, required this.controller});

  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final types = controller.clientTypes;
      final selectedTypeId = controller.selectedClientTypeId.value;
      final drafts = controller.requirementDrafts;
      final progress = controller.profileSaveProgress.value;
      final canEdit = controller.canManage || controller.canManageProfile;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (progress != null) ...[
            Text(progress, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (controller.isLoadingTypes.value)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (types.isEmpty)
            const Text(
              'No client types available.',
              style: TextStyle(color: AppColors.textMuted),
            )
          else if (controller.showClientTypePicker)
            DropdownButtonFormField<String>(
              value:
                  selectedTypeId != null &&
                          types.any((t) => t.id == selectedTypeId)
                      ? selectedTypeId
                      : null,
              items: [
                for (final t in types)
                  DropdownMenuItem(value: t.id, child: Text(t.name)),
              ],
              onChanged:
                  !canEdit || controller.isSaving.value
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
              ClientRequirementEditor(controller: controller, draft: draft),
          ],
        ],
      );
    });
  }
}
