import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/recurrence_rule_form_controller.dart';
import '../data/models/job_models.dart';
import '../utils/recurrence_rrule_builder.dart';

class RecurrenceRuleFormView extends StatelessWidget {
  const RecurrenceRuleFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(RecurrenceRuleFormController());
    return Scaffold(
      appBar: AppBar(title: const Text('Add recurrence rule')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (c.error.value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  c.error.value!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            DropdownButtonFormField<String>(
              initialValue: c.selectedContractorId.value,
              items: [
                for (final engagement in c.jobs.assignableEngagements)
                  DropdownMenuItem(
                    value: engagement.contractorId,
                    child: Text(
                      engagement.contractorName ?? engagement.contractorId,
                    ),
                  ),
              ],
              onChanged: (value) => c.selectedContractorId.value = value,
              decoration: const InputDecoration(
                labelText: 'Contractor *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: c.frequency.value,
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
                  for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                    FilterChip(
                      label: Text(weekdayRruleCodes[day]!),
                      selected: c.weekdays.contains(day),
                      onSelected: (_) => c.toggleWeekday(day),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _DateTile(
              label: 'Start date',
              value: c.startDate.value,
              onSelected: (date) => c.startDate.value = date,
            ),
            _DateTile(
              label: 'Ends on (optional)',
              value: c.endDate.value,
              onSelected: (date) => c.endDate.value = date,
            ),
            const Divider(height: 32),
            Text('Visit windows', style: Get.textTheme.titleMedium),
            for (var index = 0; index < c.windows.length; index++)
              _WindowRow(controller: c, index: index),
            TextButton.icon(
              onPressed: c.windows.length == 4 ? null : c.addWindow,
              icon: const Icon(Icons.add),
              label: const Text('Add window'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: c.taskTitlesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Task titles (one per line)',
                border: OutlineInputBorder(),
              ),
            ),
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
                      onSelected: (_) => c.toggleForm(form.formTemplateId),
                    ),
                ],
              ),
            ],
            const Divider(height: 32),
            Text('Preview', style: Get.textTheme.titleMedium),
            for (final occurrence in c.preview)
              Text(
                '${MaterialLocalizations.of(context).formatMediumDate(occurrence)}'
                ' · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(occurrence))}',
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  c.jobs.isSaving.value
                      ? null
                      : () async {
                        if (await c.save() && context.mounted) Get.back();
                      },
              child: const Text('Save recurrence rule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onSelected,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      value == null
          ? 'Never'
          : MaterialLocalizations.of(context).formatMediumDate(value!),
    ),
    trailing: const Icon(Icons.calendar_today),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (picked != null) onSelected(picked);
    },
  );
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.controller, required this.index});
  final RecurrenceRuleFormController controller;
  final int index;

  @override
  Widget build(BuildContext context) {
    final window = controller.windows[index];
    Future<void> pick(bool start) async {
      final value = start ? window.startTime : window.endTime;
      final parts = value.split(':');
      final selected = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        ),
      );
      if (selected == null) return;
      final replacement =
          '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
      controller.windows[index] =
          start
              ? TimeWindow(startTime: replacement, endTime: window.endTime)
              : TimeWindow(startTime: window.startTime, endTime: replacement);
    }

    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: () => pick(true),
            child: Text('Start ${window.startTime}'),
          ),
        ),
        Expanded(
          child: TextButton(
            onPressed: () => pick(false),
            child: Text('End ${window.endTime}'),
          ),
        ),
        if (controller.windows.length > 1)
          IconButton(
            onPressed: () => controller.removeWindow(index),
            icon: const Icon(Icons.remove_circle_outline),
          ),
      ],
    );
  }
}
