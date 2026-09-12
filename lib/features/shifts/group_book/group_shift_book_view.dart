import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/keyboard_time_field.dart';
import '../../clients/data/models/client_models.dart';
import '../../jobs/utils/required_slots_input.dart';
import '../../../shared/utils/name_sort.dart';
import '../utils/allocation_math.dart';
import '../utils/group_participant_draft.dart';
import '../utils/participant_display.dart';
import '../utils/participant_window_math.dart';
import 'group_allocation_strategy_segment.dart';
import 'group_shift_book_controller.dart';

class GroupShiftBookView extends GetView<GroupShiftBookController> {
  const GroupShiftBookView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() {
          switch (controller.step.value) {
            case GroupShiftBookController.peopleStep:
              return const Text('People');
            case GroupShiftBookController.whenStep:
              return const Text('When');
            default:
              return const Text('Review');
          }
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.clients.isEmpty) {
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
                          GroupShiftBookController.peopleStep =>
                            _PeopleStep(controller: controller),
                          GroupShiftBookController.whenStep =>
                            _WhenStep(controller: controller),
                          _ => _ReviewStep(controller: controller),
                        },
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (controller.step.value == GroupShiftBookController.maxStep)
              FormStickyActions(
                onCancel: () => Get.back(),
                primaryLabel: 'Create draft',
                onPrimary:
                    controller.isSaving.value ? null : controller.createDraft,
                isLoading: controller.isSaving.value,
              )
            else
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: PageContent(
                    width: PageContentWidth.narrow,
                    child: Row(
                      children: [
                        if (controller.step.value > 0)
                          OutlinedButton(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : controller.previousStep,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(88, 48),
                            ),
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed:
                              controller.isSaving.value
                                  ? null
                                  : controller.nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            minimumSize: const Size(88, 48),
                          ),
                          child: const Text('Next'),
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
    const labels = GroupShiftBookController.stepLabels;
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
                    color: i <= step ? AppColors.textDark : AppColors.textMuted,
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

class _PeopleStep extends StatelessWidget {
  const _PeopleStep({required this.controller});
  final GroupShiftBookController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final draft = controller.draft.value;
      final host = controller.host.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Host', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Venue / standing job only — not billed unless included below.',
            style: Get.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ClientOut>(
            value: host,
            items: [
              for (final c in sortedByName(controller.clients, (c) => c.fullName))
                DropdownMenuItem(value: c, child: Text(c.fullName)),
            ],
            onChanged: controller.selectHost,
            decoration: const InputDecoration(
              labelText: 'Host client',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include host in group'),
            subtitle: const Text('Adds the host as a billed participant'),
            value: controller.includeHost.value,
            onChanged:
                host == null
                    ? null
                    : (v) => controller.setIncludeHost(v),
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Text('Who is supported', style: Get.textTheme.titleMedium),
              ),
              TextButton.icon(
                onPressed:
                    atHardCap(draft.length)
                        ? null
                        : () => _openParticipantPicker(context),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add'),
              ),
            ],
          ),
          GroupAllocationStrategySegment(
            strategy: draft.allocationStrategy,
            onChanged: controller.setAllocationStrategy,
          ),
          const SizedBox(height: 8),
          if (!draft.isTimeBased) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Equal split'),
              value: draft.equalSplit,
              onChanged: (v) => controller.setEqualSplit(v),
            ),
            if (!draft.equalSplit) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  controller.remainingLabel,
                  style: TextStyle(
                    color:
                        sumsTo100(
                              draft.participants.map((p) => p.allocationValue),
                            )
                            ? AppColors.textMuted
                            : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ] else
            Text(
              formatShiftBoundsHint(
                controller.scheduledStart.value,
                controller.scheduledEnd.value,
              ),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          if (draft.participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Add at least one participant.'),
            ),
          for (final row in draft.participants)
            _ParticipantDraftRow(
              row: row,
              timeBased: draft.isTimeBased,
              equalSplit: draft.equalSplit,
              onRemove: () => controller.removeParticipant(row.participantId),
              onAllocationChanged:
                  draft.isTimeBased || draft.equalSplit
                      ? null
                      : (v) =>
                          controller.setAllocation(row.participantId, v),
              onEditWindows:
                  draft.isTimeBased
                      ? () => controller.editWindows(row)
                      : null,
            ),
        ],
      );
    });
  }

  Future<void> _openParticipantPicker(BuildContext context) async {
    controller.clientSearch.value = '';
    final picked = await Navigator.of(context).push<ClientOut>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ParticipantPickerPage(controller: controller),
      ),
    );
    if (picked != null) {
      await controller.addParticipant(picked);
    }
  }
}

class _ParticipantDraftRow extends StatelessWidget {
  const _ParticipantDraftRow({
    required this.row,
    required this.timeBased,
    required this.equalSplit,
    required this.onRemove,
    this.onAllocationChanged,
    this.onEditWindows,
  });

  final GroupParticipantDraft row;
  final bool timeBased;
  final bool equalSplit;
  final VoidCallback onRemove;
  final ValueChanged<double>? onAllocationChanged;
  final VoidCallback? onEditWindows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 12,
          title: Text(row.displayName),
          subtitle: Text(
            timeBased
                ? formatWindowsSummary(row.timeWindows)
                : equalSplit
                ? '${row.allocationValue.toStringAsFixed(2)}% · equal'
                : 'Capacity %',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          onTap: timeBased ? onEditWindows : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (timeBased)
                IconButton(
                  tooltip: 'Edit windows',
                  onPressed: onEditWindows,
                  icon: const Icon(Icons.schedule_outlined),
                ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        if (!timeBased && !equalSplit && onAllocationChanged != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              initialValue: row.allocationValue.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Capacity %',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (raw) {
                final v = double.tryParse(raw);
                if (v != null) onAllocationChanged!(v);
              },
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _ParticipantPickerPage extends StatelessWidget {
  const _ParticipantPickerPage({required this.controller});
  final GroupShiftBookController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add participant')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search clients',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => controller.clientSearch.value = v,
            ),
          ),
          Expanded(
            child: Obx(() {
              final candidates = controller.pickerCandidates;
              if (candidates.isEmpty) {
                return const Center(child: Text('No clients to add.'));
              }
              return ListView.separated(
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = candidates[index];
                  return ListTile(
                    minVerticalPadding: 14,
                    title: Text(c.fullName),
                    onTap: () => Navigator.of(context).pop(c),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _WhenStep extends StatelessWidget {
  const _WhenStep({required this.controller});
  final GroupShiftBookController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final start = controller.scheduledStart.value;
      final end = controller.scheduledEnd.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateTile(
            label: 'Start date',
            value: start,
            onSelected: (d) {
              controller.scheduledStart.value = DateTime(
                d.year,
                d.month,
                d.day,
                start.hour,
                start.minute,
              );
            },
          ),
          KeyboardTimeField(
            label: 'Start time',
            value: TimeOfDay(hour: start.hour, minute: start.minute),
            onChanged: (time) {
              controller.scheduledStart.value = DateTime(
                start.year,
                start.month,
                start.day,
                time.hour,
                time.minute,
              );
            },
          ),
          const SizedBox(height: 8),
          _DateTile(
            label: 'End date',
            value: end,
            onSelected: (d) {
              controller.scheduledEnd.value = DateTime(
                d.year,
                d.month,
                d.day,
                end.hour,
                end.minute,
              );
            },
          ),
          KeyboardTimeField(
            label: 'End time',
            value: TimeOfDay(hour: end.hour, minute: end.minute),
            onChanged: (time) {
              controller.scheduledEnd.value = DateTime(
                end.year,
                end.month,
                end.day,
                time.hour,
                time.minute,
              );
            },
          ),
          const SizedBox(height: 16),
          _NumberStepper(
            label: 'Roster slots',
            value: controller.requiredSlots.value,
            min: 1,
            max: kRequiredSlotsUiMax,
            onChanged: (n) => controller.requiredSlots.value = n,
          ),
          const SizedBox(height: 12),
          _NumberStepper(
            label: 'Workers planned',
            value: controller.workerCount.value,
            min: 1,
            max: kRequiredSlotsUiMax,
            onChanged: (n) => controller.workerCount.value = n,
          ),
          if (controller.slotsMismatch) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.openSlotBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Workers planned (${controller.workerCount.value}) differs from '
                'roster slots (${controller.requiredSlots.value}).',
                style: const TextStyle(color: AppColors.openSlot),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.controller});
  final GroupShiftBookController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final draft = controller.draft.value;
      final host = controller.host.value;
      final start = controller.scheduledStart.value;
      final end = controller.scheduledEnd.value;
      final n = draft.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Host', style: Get.textTheme.titleMedium),
          Text(host?.fullName ?? '—'),
          const SizedBox(height: 12),
          Text('Participants', style: Get.textTheme.titleMedium),
          Text(
            rosterTileLabel(draft.participants.map((p) => p.displayName)),
          ),
          Text(
            '${staffParticipantLabel(controller.workerCount.value, n)} · '
            '${draft.isTimeBased
                ? 'time windows'
                : draft.equalSplit
                ? 'equal split'
                : 'custom %'} · '
            '$n participant${n == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Text('When', style: Get.textTheme.titleMedium),
          Text(_fmt(start)),
          Text(_fmt(end)),
          Text(
            'Slots ${controller.requiredSlots.value} · '
            'Workers planned ${controller.workerCount.value}',
          ),
          const SizedBox(height: 16),
          const Text(
            'Creates a draft group shift. Publish from shift detail when ready.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      );
    });
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: Get.textTheme.titleMedium),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
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
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}',
      ),
      trailing: const Icon(Icons.calendar_today_outlined),
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
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

String _fmt(DateTime dt) {
  final l = dt;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}
