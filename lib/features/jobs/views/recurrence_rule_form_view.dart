import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/app_date_field.dart';
import '../../../shared/widgets/keyboard_time_field.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../controllers/recurrence_rule_form_controller.dart';
import '../utils/recurrence_rrule_builder.dart';
import '../utils/required_slots_input.dart';
import '../widgets/worker_slot_picker.dart';

class RecurrenceRuleFormView extends StatelessWidget {
  const RecurrenceRuleFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(RecurrenceRuleFormController());
    return Scaffold(
      appBar: AppBar(title: const Text('Add weekly pattern')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (c.error.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        c.error.value!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    value: c.requiredSlots.value,
                    items: [
                      for (var n = 1; n <= kRequiredSlotsUiMax; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (value) {
                      if (value != null) c.requiredSlots.value = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Needs how many people',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WorkerSlotPicker(
                    slots: List<String?>.from(c.selectedContractorIds),
                    engagements: [
                      for (final engagement in c.jobs.assignableEngagements)
                        WorkerSlotEngagement(
                          contractorId: engagement.contractorId,
                          displayName:
                              engagement.contractorName ??
                              engagement.contractorId,
                        ),
                    ],
                    enabled: !c.jobs.isSaving.value,
                    onChanged: (index, contractorId) {
                      final ok = c.setContractorAt(index, contractorId);
                      if (!ok) {
                        c.error.value =
                            'That worker is already assigned to another slot.';
                        c.selectedContractorIds.refresh();
                      } else if (c.error.value?.contains('already assigned') ==
                          true) {
                        c.error.value = null;
                      }
                      return ok;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Creates upcoming shifts. Unfilled slots stay open to claim.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<RecurrenceFrequency>(
                    value: c.frequency.value,
                    items:
                        RecurrenceFrequency.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.name.capitalizeFirst!),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) c.frequency.value = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Repeats',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (c.requiresWeekdays) ...[
                    const SizedBox(height: 12),
                    const Text('On days *'),
                    Wrap(
                      children: [
                        for (
                          var day = DateTime.monday;
                          day <= DateTime.sunday;
                          day++
                        )
                          FilterChip(
                            label: Text(weekdayRruleCodes[day]!),
                            selected: c.weekdays.contains(day),
                            onSelected: (_) => c.toggleWeekday(day),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  AppDateField(
                    label: 'Start date',
                    value: c.startDate.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    onChanged: (date) => c.startDate.value = date,
                  ),
                  const SizedBox(height: 12),
                  AppDateField(
                    label: 'Ends on',
                    value: c.endDate.value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    onChanged: (date) => c.endDate.value = date,
                  ),
                  const Divider(height: 32),
                  Text('Participant shifts', style: Get.textTheme.titleMedium),
                  for (var index = 0; index < c.windows.length; index++)
                    _WindowRow(controller: c, index: index),
                  TextButton.icon(
                    onPressed: c.windows.length == 4 ? null : c.addWindow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add participant shift'),
                  ),
                  const SizedBox(height: 12),
                  Text('Task titles', style: Get.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text(
                    'One task per line. Copied onto generated visits.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: c.taskTitlesCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Further instructions (optional)',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (c.taskSupportSlots.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Task NDIS items (optional)',
                      style: Get.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'When set, invoice export can use one line per coded task.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    for (var i = 0; i < c.taskSupportSlots.length; i++) ...[
                      const SizedBox(height: 12),
                      Text(
                        c.taskTitles.length > i
                            ? c.taskTitles[i]
                            : 'Task ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      NdisSupportItemPicker(
                        supportItemCode: c.taskSupportSlots[i].supportItemCode,
                        supportItemName: c.taskSupportSlots[i].supportItemName,
                        enabled: !c.jobs.isSaving.value,
                        labelText: 'NDIS item',
                        onChanged: ({
                          required String? supportItemCode,
                          required String? supportItemName,
                        }) {
                          c.setTaskSupportItem(
                            index: i,
                            supportItemCode: supportItemCode,
                            supportItemName: supportItemName,
                          );
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  if (c.jobs.formCatalog.isNotEmpty) ...[
                    const Text('Required forms'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final form in c.jobs.formCatalog)
                          FilterChip(
                            label: Text(form.name),
                            selected: c.selectedFormTemplateIds.contains(
                              form.formTemplateId,
                            ),
                            onSelected:
                                (_) => c.toggleForm(form.formTemplateId),
                          ),
                      ],
                    ),
                  ] else
                    const Text(
                      'Attach form templates via Manage templates on the job first.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  const Divider(height: 32),
                  Text('Preview', style: Get.textTheme.titleMedium),
                  const Text(
                    'Times use your device timezone while tenant timezone is unavailable.',
                  ),
                  for (final preview in c.preview)
                    Text(
                      '${MaterialLocalizations.of(context).formatMediumDate(preview.date)}, '
                      '${preview.window.startTime}–${preview.window.endTime}',
                    ),
                  const SizedBox(height: 16),
                  AsyncElevatedButton(
                    onPressed: () async {
                      if (await c.save() && context.mounted) Get.back();
                    },
                    isLoading: c.jobs.isSaving.value,
                    child: const Text('Save recurrence rule'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.controller, required this.index});
  final RecurrenceRuleFormController controller;
  final int index;

  TimeOfDay _parse(String value) {
    return parseHhMm(value) ?? const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    final window = controller.windows[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: KeyboardTimeField(
              label: 'Start time',
              value: _parse(window.startTime),
              onChanged: (time) {
                controller.setWindowStartTime(index, formatHhMm(time));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: KeyboardTimeField(
              label: 'End time',
              value: _parse(window.endTime),
              onChanged: (time) {
                controller.setWindowEndTime(index, formatHhMm(time));
              },
            ),
          ),
          if (controller.windows.length > 1)
            IconButton(
              onPressed: () => controller.removeWindow(index),
              icon: const Icon(Icons.remove_circle_outline),
            ),
        ],
      ),
    );
  }
}
