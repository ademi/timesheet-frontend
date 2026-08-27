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
      final drafts =
          controller.requirementDrafts
              .where(
                (d) => !ClientsController.isOverviewOwnedRequirement(
                  d.requirement.requirementKey,
                ),
              )
              .toList();
      final progress = controller.profileSaveProgress.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile & docs',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (progress != null) ...[
            Text(progress, style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          if (controller.isLoadingRequirements.value) ...[
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (drafts.isNotEmpty) ...[
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
          ] else if (!controller.isLoadingRequirements.value) ...[
            const Text(
              'No profile requirements for this client type.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ],
      );
    });
  }
}
