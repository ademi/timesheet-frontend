import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../jobs/widgets/worker_slot_picker.dart';
import '../../shared/assign_context_labels.dart';
import '../roster_composer_controller.dart';
import 'publish_section.dart';
import 'repeat_section.dart';

/// Step 6 — workers + publish (+ Repeat preferred/generate when enabled).
class ComposerWorkersSection extends StatefulWidget {
  const ComposerWorkersSection({super.key});

  @override
  State<ComposerWorkersSection> createState() => _ComposerWorkersSectionState();
}

class _ComposerWorkersSectionState extends State<ComposerWorkersSection> {
  late final RosterComposerController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RosterComposerController>();
    // Section-open load — never blocks Save draft.
    controller.onWorkersSectionOpened();
  }

  Color _availabilityColor(String label) {
    return switch (label) {
      'Leave' => AppColors.error,
      'Busy' => AppColors.openSlot,
      'Outside hours' => AppColors.openSlot,
      'Unknown' => AppColors.textMuted,
      _ => AppColors.success,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = controller.draft.value.workerCount;
      final selected = controller.draft.value.contractorIds;
      final loading = controller.assignContextLoading.value;
      final err = controller.assignContextError.value;
      final workers = controller.assignableEngagements;

      final slotList = List<String?>.generate(
        controller.showsWorkerCount ? count : 1,
        (i) => i < selected.length ? selected[i] : null,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Workers', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Optional assign now, or leave open for claim. Save draft anytime.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 2, child: LinearProgressIndicator()),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: Text('…')),
                      Chip(label: Text('…')),
                    ],
                  ),
                ],
              ),
            ),
          if (err != null) ...[
            Text(
              err,
              key: const Key('composer-assign-context-error'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
            TextButton(
              key: const Key('composer-assign-context-retry'),
              onPressed: controller.retryAssignContext,
              child: const Text('Retry'),
            ),
          ],
          WorkerSlotPicker(
            key: const Key('composer-worker-picker'),
            slots: slotList,
            engagements: [
              for (final e in workers)
                WorkerSlotEngagement(
                  contractorId: e.contractorId,
                  displayName: e.displayName,
                ),
            ],
            enabled: !loading,
            onChanged: (index, contractorId) {
              if (contractorId != null) {
                final label = controller.availabilityLabelForContractor(
                  contractorId,
                );
                if (assignLabelRequiresOverrideReason(label)) {
                  controller.setContractorSlot(index, contractorId);
                  return false;
                }
              }
              controller.setContractorSlot(index, contractorId);
              return true;
            },
            trailingForSlot: (index, contractorId) {
              if (contractorId == null) return null;
              final label = controller.availabilityLabelForContractor(
                contractorId,
              );
              return Text(
                key: Key('composer-avail-$contractorId'),
                ' · $label',
                style: TextStyle(
                  fontSize: 12,
                  color: _availabilityColor(label),
                ),
              );
            },
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${selected.length} worker${selected.length == 1 ? '' : 's'} selected.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 28),
          const ComposerRepeatSection(
            mode: ComposerRepeatUiMode.preferredAndGenerate,
          ),
          const SizedBox(height: 28),
          const ComposerPublishSection(),
        ],
      );
    });
  }
}
