import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../../clients/widgets/ndis_capture_prompt.dart';
import '../widgets/care_plan_tasks_field.dart';
import '../controllers/unified_support_controller.dart';
import '../utils/recurrence_rrule_builder.dart';
import '../utils/unified_support_args.dart';

class UnifiedSupportView extends GetView<UnifiedSupportController> {
  const UnifiedSupportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          switch (controller.step.value) {
            case 0:
              return const Text('Support type');
            case 1:
              return const Text('Location');
            case 2:
              return Text(
                controller.isOneSession ? 'Date & time' : 'Pattern & time',
              );
            default:
              return const Text('Templates & NDIS');
          }
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.client.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _StepIndicator(step: controller.step.value),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        switch (controller.step.value) {
                          0 => _TypeStep(controller: controller),
                          1 => _LocationStep(controller: controller),
                          2 => _ScheduleStep(controller: controller),
                          _ => _TemplatesStep(controller: controller),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: Row(
                    children: [
                      if (controller.step.value > 0)
                        OutlinedButton(
                          onPressed: controller.isSaving.value
                              ? null
                              : controller.previousStep,
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      if (controller.step.value < UnifiedSupportController.maxStep)
                        ElevatedButton(
                          onPressed: controller.isSaving.value
                              ? null
                              : controller.nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                          child: const Text('Next'),
                        )
                      else
                        AsyncElevatedButton(
                          onPressed: controller.submit,
                          isLoading: controller.isSaving.value,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                          ),
                          child: Text(
                            controller.isOneSession
                                ? 'Book session'
                                : 'Save and fill roster',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Type', 'Location', 'Schedule', 'Details'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= step ? AppColors.primary : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    color: i <= step
                        ? AppColors.textDark
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeStep extends StatelessWidget {
  const _TypeStep({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What do you want to schedule?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          selected: controller.mode.value == UnifiedSupportMode.oneSession,
          title: 'One session',
          subtitle: 'Book a single shift for this client.',
          icon: Icons.event_outlined,
          onTap: () => controller.setMode(UnifiedSupportMode.oneSession),
        ),
        const SizedBox(height: 8),
        _ModeCard(
          selected: controller.mode.value == UnifiedSupportMode.ongoing,
          title: 'Ongoing support',
          subtitle: 'Set a repeating pattern and fill the roster.',
          icon: Icons.event_repeat_outlined,
          onTap: () => controller.setMode(UnifiedSupportMode.ongoing),
        ),
        const SizedBox(height: 16),
        if (controller.needsClientPicker ||
            controller.clients.isNotEmpty && controller.client.value == null)
          DropdownButtonFormField<String>(
            value: controller.client.value?.id,
            isExpanded: true,
            items: [
              for (final c in controller.clients)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(c.fullName, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: controller.selectClientById,
            decoration: const InputDecoration(
              labelText: 'Client *',
              border: OutlineInputBorder(),
            ),
          )
        else if (controller.client.value != null)
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Client',
              border: OutlineInputBorder(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.client.value!.fullName),
                if (controller.clientNdisNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'NDIS ${controller.clientNdisNumber}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (controller.showNdisCapturePrompt) ...[
          const SizedBox(height: 12),
          NdisCapturePrompt(onAddDetails: controller.openClientDetailsForNdis),
        ],
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationStep extends StatelessWidget {
  const _LocationStep({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    final empty = controller.blocksWithoutSites;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Where will this support happen?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),
        if (empty) ...[
          const _AmberNotice(
            message:
                'This client has no locations yet. Add a site before continuing.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.openAddSite,
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add site for this client'),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            value: controller.selectedSiteId.value,
            items: [
              for (final site in controller.sites)
                DropdownMenuItem(value: site.id, child: Text(site.name)),
            ],
            onChanged: (v) => controller.selectedSiteId.value = v,
            decoration: const InputDecoration(
              labelText: 'Client location *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.openAddSite,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add another location'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ScheduleStep extends StatelessWidget {
  const _ScheduleStep({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isOneSession) {
      return _OneSessionSchedule(controller: controller);
    }
    return _OngoingSchedule(controller: controller);
  }
}

class _OneSessionSchedule extends StatelessWidget {
  const _OneSessionSchedule({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    final start = controller.oneSessionStart.value;
    final end = controller.oneSessionEnd.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start'),
          subtitle: Text(_fmtDateTime(start)),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final next = await _pickDateTime(context, start);
            if (next != null) controller.oneSessionStart.value = next;
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End'),
          subtitle: Text(_fmtDateTime(end)),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final next = await _pickDateTime(context, end);
            if (next != null) controller.oneSessionEnd.value = next;
          },
        ),
        const SizedBox(height: 8),
        _SlotsStepper(controller: controller),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Publish immediately'),
          value: controller.publishImmediately.value,
          onChanged: (v) => controller.publishImmediately.value = v,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: controller.selectedContractorId.value,
          items: [
            const DropdownMenuItem(value: null, child: Text('Unfilled')),
            for (final engagement in controller.assignableEngagements)
              DropdownMenuItem(
                value: engagement.contractorId,
                child: Text(
                  engagement.contractorName ?? engagement.contractorId,
                ),
              ),
          ],
          onChanged: (value) => controller.selectedContractorId.value = value,
          decoration: const InputDecoration(
            labelText: 'Worker (optional)',
            border: OutlineInputBorder(),
            helperText:
                'Assign a worker to book a visit with shift tasks immediately.',
          ),
        ),
      ],
    );
  }
}

class _OngoingSchedule extends StatelessWidget {
  const _OngoingSchedule({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    final multiSlot = controller.requiredSlots.value > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<RecurrenceFrequency>(
          value: controller.frequency.value,
          items: [
            for (final value in RecurrenceFrequency.values)
              DropdownMenuItem(
                value: value,
                child: Text(value.name.capitalizeFirst!),
              ),
          ],
          onChanged: (value) {
            if (value != null) controller.frequency.value = value;
          },
          decoration: const InputDecoration(
            labelText: 'Repeats',
            border: OutlineInputBorder(),
          ),
        ),
        if (controller.requiresWeekdays) ...[
          const SizedBox(height: 12),
          const Text('On days *'),
          Wrap(
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                FilterChip(
                  label: Text(weekdayRruleCodes[day]!),
                  selected: controller.weekdays.contains(day),
                  onSelected: (_) => controller.toggleWeekday(day),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _DateTile(
          label: 'Start date',
          value: controller.startDate.value,
          onSelected: (d) => controller.startDate.value = d,
        ),
        _DateTile(
          label: 'Ends on',
          value: controller.endDate.value,
          onSelected: (d) => controller.endDate.value = d,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Start time'),
          subtitle: Text(formatSupportTimeOfDay(controller.startTime.value)),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: controller.startTime.value,
            );
            if (picked != null) controller.startTime.value = picked;
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('End time'),
          subtitle: Text(formatSupportTimeOfDay(controller.endTime.value)),
          trailing: const Icon(Icons.access_time),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: controller.endTime.value,
            );
            if (picked != null) controller.endTime.value = picked;
          },
        ),
        const SizedBox(height: 8),
        _SlotsStepper(controller: controller),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: multiSlot ? null : controller.selectedContractorId.value,
          items: [
            const DropdownMenuItem(value: null, child: Text('Unfilled')),
            if (!multiSlot)
              for (final engagement in controller.assignableEngagements)
                DropdownMenuItem(
                  value: engagement.contractorId,
                  child: Text(
                    engagement.contractorName ?? engagement.contractorId,
                  ),
                ),
          ],
          onChanged: multiSlot
              ? null
              : (value) => controller.selectedContractorId.value = value,
          decoration: InputDecoration(
            labelText: 'Worker (optional)',
            border: const OutlineInputBorder(),
            helperText: multiSlot
                ? 'Assign workers from the roster when multiple slots are needed'
                : null,
          ),
        ),
      ],
    );
  }
}

class _SlotsStepper extends StatelessWidget {
  const _SlotsStepper({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Required workers',
        border: OutlineInputBorder(),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: controller.requiredSlots.value > 1
                ? controller.decrementSlots
                : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Expanded(
            child: Text(
              '${controller.requiredSlots.value}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: controller.requiredSlots.value < 8
                ? controller.incrementSlots
                : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _TemplatesStep extends StatelessWidget {
  const _TemplatesStep({required this.controller});
  final UnifiedSupportController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.isOngoing) ...[
          TextField(
            controller: controller.titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Title *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (controller.showNdisCapturePrompt) ...[
          NdisCapturePrompt(onAddDetails: controller.openClientDetailsForNdis),
          const SizedBox(height: 12),
        ] else if (controller.clientNdisNumber != null) ...[
          Text(
            'NDIS ${controller.clientNdisNumber}',
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
        ],
        CarePlanTasksField(
          taskTitlesCtrl: controller.taskTitlesCtrl,
          otherTitleCtrl: controller.otherTitleCtrl,
          showOtherTitleField: controller.showOtherTitleField,
          onPresetSelected: controller.onTaskPresetSelected,
          onAppendOtherTitle: controller.appendOtherCarePlanTask,
          sectionTitle: controller.isOngoing ? 'Care plan tasks' : 'Shift tasks',
          helperText: controller.isOngoing
              ? 'Optional task titles copied onto generated visits.'
              : 'Optional task titles for this booked visit (requires a worker).',
        ),
        const SizedBox(height: 16),
        NdisSupportItemPicker(
          supportItemCode: controller.supportItemCode.value,
          supportItemName: controller.supportItemName.value,
          enabled: !controller.isSaving.value,
          labelText: 'NDIS support item (optional)',
          onChanged: ({
            required String? supportItemCode,
            required String? supportItemName,
          }) {
            controller.setSupportItem(
              supportItemCode: supportItemCode,
              supportItemName: supportItemName,
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Optional default for generated or booked visits.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        const Text(
          'Form templates',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Attach visit forms to this support (optional).',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        if (controller.formTemplates.isEmpty)
          const Text(
            'No form templates yet. Create them under Settings → Form templates.',
            style: TextStyle(color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in controller.formTemplates)
                FilterChip(
                  label: Text(t.name),
                  selected: controller.selectedFormTemplateIds.contains(t.id),
                  onSelected: (_) => controller.toggleFormTemplate(t.id),
                ),
            ],
          ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _AmberNotice extends StatelessWidget {
  const _AmberNotice({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, color: AppColors.openSlot),
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

String _fmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
