import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/widgets/app_date_field.dart';
import '../../../../jobs/utils/recurrence_rrule_builder.dart';
import '../../../../jobs/widgets/worker_slot_picker.dart';
import '../roster_composer_controller.dart';

/// A7 Repeat section — frequency, horizon, publish_policy, soft preferred.
class ComposerRepeatSection extends StatefulWidget {
  const ComposerRepeatSection({super.key});

  @override
  State<ComposerRepeatSection> createState() => _ComposerRepeatSectionState();
}

class _ComposerRepeatSectionState extends State<ComposerRepeatSection> {
  late final RosterComposerController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RosterComposerController>();
    controller.onRepeatSectionOpened();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.draft.value.repeatEnabled;
      final generating = controller.isGeneratingRepeat.value;
      final outcome = controller.generateOutcomeMessage.value;
      final err = controller.repeatError.value;
      final slots = controller.draft.value.requiredSlots;
      final preferred = controller.preferredContractorIds;
      final slotList = List<String?>.generate(
        slots < 1 ? 1 : slots,
        (i) => i < preferred.length ? preferred[i] : null,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Repeat', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Turn on to write a recurrence template from this draft.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Repeat this support'),
            value: enabled,
            onChanged: controller.setRepeatEnabled,
          ),
          if (enabled) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<RecurrenceFrequency>(
              value: controller.repeatFrequency.value,
              items: [
                for (final value in RecurrenceFrequency.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(value.name.capitalizeFirst!),
                  ),
              ],
              onChanged: (value) {
                if (value != null) controller.setRepeatFrequency(value);
              },
              decoration: const InputDecoration(
                labelText: 'Repeats',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (controller.repeatRequiresWeekdays) ...[
              const SizedBox(height: 12),
              const Text('On days *'),
              Wrap(
                spacing: 6,
                children: [
                  for (
                    var day = DateTime.monday;
                    day <= DateTime.sunday;
                    day++
                  )
                    FilterChip(
                      label: Text(weekdayRruleCodes[day]!),
                      selected: controller.repeatWeekdays.contains(day),
                      onSelected: (_) => controller.toggleRepeatWeekday(day),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            AppDateField(
              label: 'Start date',
              value: controller.repeatStartDate.value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              onChanged: controller.setRepeatStartDate,
              isDense: true,
            ),
            const SizedBox(height: 12),
            AppDateField(
              label: 'Ends on',
              value: controller.repeatEndDate.value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              onChanged: controller.setRepeatEndDate,
              isDense: true,
            ),
            const SizedBox(height: 16),
            Text('When generated', style: Get.textTheme.titleSmall),
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'draft', label: Text('Draft')),
                ButtonSegment(value: 'published', label: Text('Open holes')),
              ],
              selected: {controller.repeatPublishPolicy.value},
              onSelectionChanged: (next) {
                if (next.isNotEmpty) {
                  controller.setRepeatPublishPolicy(next.first);
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              controller.repeatPublishPolicy.value == 'draft'
                  ? 'Draft shifts stay off the claim board until published.'
                  : 'Published shifts keep open slots for workers to claim.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              'Suggested workers (not auto-assigned)',
              style: Get.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'Soft suggestions only. Generate never auto-rosters these workers.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            WorkerSlotPicker(
              slots: slotList,
              engagements: [
                for (final e in controller.assignableEngagements)
                  WorkerSlotEngagement(
                    contractorId: e.contractorId,
                    displayName: e.displayName,
                  ),
              ],
              onChanged: (index, contractorId) {
                controller.setPreferredContractorAt(index, contractorId);
                return true;
              },
            ),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(
                err,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            if (generating)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (outcome != null) ...[
              const SizedBox(height: 8),
              Text(
                outcome,
                style: const TextStyle(color: AppColors.slate700, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed:
                      generating
                          ? null
                          : () => controller.generateRepeatHorizon(),
                  child: const Text('Generate next 14 days'),
                ),
                if (controller.recurrenceRuleId.value != null)
                  TextButton(
                    onPressed:
                        generating
                            ? null
                            : () => controller.splitThisAndFuture(),
                    child: const Text('This and future'),
                  ),
              ],
            ),
          ],
        ],
      );
    });
  }
}
