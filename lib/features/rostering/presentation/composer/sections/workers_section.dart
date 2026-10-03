import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../roster_composer_controller.dart';

/// Stage A workers shell — assign-context chips land in Task 4.
class ComposerWorkersSection extends GetView<RosterComposerController> {
  const ComposerWorkersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.draft.value.workerCount;
      final slots = controller.draft.value.requiredSlots;
      final selected = controller.draft.value.contractorIds;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Workers', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Optional assign now, or leave open for claim.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (controller.showsWorkerCount) ...[
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: count,
                    decoration: const InputDecoration(
                      labelText: 'Workers planned',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (var n = 1; n <= 8; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setWorkerCount(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: slots,
                    decoration: const InputDecoration(
                      labelText: 'Open slots',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (var n = 1; n <= 8; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setRequiredSlots(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            selected.isEmpty
                ? 'No workers selected yet.'
                : '${selected.length} worker${selected.length == 1 ? '' : 's'} selected.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          const Text(
            'Availability chips load when assign-context is wired (Task 4).',
            style: TextStyle(color: AppColors.slate500, fontSize: 12),
          ),
        ],
      );
    });
  }
}
