import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../shifts/utils/allocation_math.dart';
import '../roster_composer_controller.dart';

class ComposerPeopleSection extends GetView<RosterComposerController> {
  const ComposerPeopleSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ids = controller.draft.value.participantIds;
      final showAlloc = controller.showsAllocation;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('People', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            controller.isGroup
                ? 'Participants on this session (max 32).'
                : 'Client for this session.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (ids.isEmpty)
            const Text(
              'Add a participant',
              style: TextStyle(color: AppColors.textMuted),
            ),
          for (final id in ids)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(controller.participantName(id) ?? id),
              trailing:
                  controller.isGroup
                      ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => controller.removeParticipant(id),
                      )
                      : null,
            ),
          if (showAlloc) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Equal split'),
              value: controller.draft.value.equalSplit,
              onChanged: controller.setEqualSplit,
            ),
            Text(
              'Allocation ${controller.draft.value.equalSplit ? 'equal' : 'custom'}',
              key: const Key('composer-allocation'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search clients',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => controller.clientSearch.value = v,
          ),
          const SizedBox(height: 8),
          for (final c in controller.pickerCandidates.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.fullName),
              trailing: const Icon(Icons.add),
              onTap: () => controller.addParticipant(c),
            ),
          if (atHardCap(ids.length))
            const Text(
              'Groups are limited to 32 participants',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
        ],
      );
    });
  }
}
