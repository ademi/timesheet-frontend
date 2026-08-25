import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../controllers/recurrence_rule_form_controller.dart';
import '../utils/recurrence_rrule_builder.dart';

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
            DropdownButtonFormField<String>(
              value: c.soleContractorId,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Unfilled (leave open to claim)'),
                ),
                for (final engagement in c.jobs.assignableEngagements)
                  DropdownMenuItem(
                    value: engagement.contractorId,
                    child: Text(
                      engagement.contractorName ?? engagement.contractorId,
                    ),
                  ),
              ],
              onChanged: c.selectSoleContractor,
              decoration: const InputDecoration(
                labelText: 'Worker (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: c.requiredSlots.value,
              items: [
                for (var n = 1; n <= 8; n++)
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
              label: 'Ends on',
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
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              for (var i = 0; i < c.taskSupportSlots.length; i++) ...[
                const SizedBox(height: 12),
                Text(
                  c.taskTitles.length > i ? c.taskTitles[i] : 'Task ${i + 1}',
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
                      onSelected: (_) => c.toggleForm(form.formTemplateId),
                    ),
                ],
              ),
            ] else
              const Text(
                'Attach form templates via Manage templates on the job first.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onSelected,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(MaterialLocalizations.of(context).formatMediumDate(value)),
    trailing: const Icon(Icons.calendar_today),
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value,
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
      if (start) {
        controller.setWindowStartTime(index, replacement);
      } else {
        controller.setWindowEndTime(index, replacement);
      }
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
