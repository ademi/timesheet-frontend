import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/utils/allocation_math.dart';
import '../../shifts/utils/participant_display.dart';
import '../../shifts/widgets/shift_slot_pips.dart';
import '../../visits/controllers/staff_visits_controller.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class StaffShiftDetailView extends StatefulWidget {
  const StaffShiftDetailView({super.key});

  @override
  State<StaffShiftDetailView> createState() => _StaffShiftDetailViewState();
}

class _StaffShiftDetailViewState extends State<StaffShiftDetailView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<StaffVisitsController>();
    c.hydrateShiftFromArgs();
    c.refreshSelectedShift();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffVisitsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Shift')),
      body: Obx(() {
        final shift = controller.selectedShift.value;
        final err = controller.errorMessage.value;
        if (shift == null) {
          if (controller.isRefreshing.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text('Shift not loaded.'));
        }
        final active = activeParticipants(shift.participants);
        final n = active.length;
        final equal =
            active.isNotEmpty &&
            sumsTo100(active.map((p) => p.allocationValue ?? 0));
        return Column(
          children: [
            if (controller.isRefreshing.value)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        if (controller.canManage &&
                            shift.status == 'draft') ...[
                          _PublishStrip(
                            shift: shift,
                            participantCount: n,
                            equalSplit: equal,
                            isSaving: controller.isSaving.value,
                            onPublish: controller.publishSelectedShift,
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(shift.jobTitle, style: Get.textTheme.titleMedium),
                        if (shift.clientName?.isNotEmpty == true)
                          Text(
                            'Host: ${shift.clientName}',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        const SizedBox(height: 4),
                        Text('Status: ${shift.status}'),
                        Text('Start: ${_fmt(shift.scheduledStart)}'),
                        Text('End: ${_fmt(shift.scheduledEnd)}'),
                        if (shift.locationLabel?.isNotEmpty == true)
                          Text('Location: ${shift.locationLabel}'),
                        const SizedBox(height: 8),
                        Text(
                          'Staff:participant ${staffParticipantLabel(shift.workerCount, n)}',
                        ),
                        ShiftSlotPips(
                          requiredSlots: shift.requiredSlots,
                          filledSlots: shift.filledSlots,
                        ),
                        Text(
                          '${shift.filledSlots} of ${shift.requiredSlots} filled · '
                          '${shift.openSlots} open',
                        ),
                        if (shift.status == 'draft' && controller.canManage) ...[
                          const SizedBox(height: 12),
                          _WorkerCountEditor(
                            workerCount: shift.workerCount,
                            requiredSlots: shift.requiredSlots,
                            enabled: !controller.isSaving.value,
                            onSave: controller.patchSelectedShiftWorkerCount,
                          ),
                        ] else ...[
                          Text('Workers planned: ${shift.workerCount}'),
                        ],
                        if (shift.warnings.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final w in shift.warnings)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                w,
                                style: const TextStyle(
                                  color: AppColors.openSlot,
                                ),
                              ),
                            ),
                        ],
                        const Divider(height: 32),
                        _ParticipantsSection(
                          shift: shift,
                          active: active,
                          canManage: controller.canManage,
                          isSaving: controller.isSaving.value,
                          onEdit: controller.openEditGroup,
                          onRemove: controller.openRemoveParticipant,
                        ),
                        const Divider(height: 32),
                        Text('Assignments', style: Get.textTheme.titleMedium),
                        if (shift.assignments.isEmpty)
                          const Text('No workers assigned yet.'),
                        for (final a in shift.assignments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(a.contractorName),
                            subtitle: Text(
                              '${a.source} · ${a.status}'
                              '${a.visitStatus != null ? ' · ${a.visitStatus}' : ''}',
                            ),
                            trailing:
                                controller.canManage && a.status == 'active'
                                    ? TextButton(
                                      onPressed:
                                          controller.isSaving.value
                                              ? null
                                              : () =>
                                                  controller.releaseAssignment(
                                                    shiftId: shift.id,
                                                    contractorId:
                                                        a.contractorId,
                                                    workerName:
                                                        a.contractorName,
                                                  ),
                                      child: const Text('Release'),
                                    )
                                    : const Icon(Icons.chevron_right),
                            onTap:
                                () => controller.openAssignmentVisit(a.visitId),
                          ),
                        if (controller.canManage &&
                            shift.status != 'cancelled' &&
                            shift.openSlots > 0) ...[
                          const Divider(height: 32),
                          Text(
                            'Assign worker',
                            style: Get.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed:
                                controller.isSaving.value
                                    ? null
                                    : () => _showAssignPicker(
                                      context,
                                      controller,
                                      shift,
                                    ),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Choose contractor'),
                          ),
                        ],
                        const Divider(height: 32),
                        _AllocationHistorySection(controller: controller),
                        if (controller.canManage &&
                            shift.status == 'published') ...[
                          const Divider(height: 32),
                          AsyncOutlinedButton(
                            onPressed: controller.cancelSelectedShift,
                            isLoading: controller.isSaving.value,
                            child: const Text('Cancel shift'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showAssignPicker(
    BuildContext context,
    StaffVisitsController controller,
    ShiftOut shift,
  ) async {
    final engagements = controller.assignableEngagements;
    if (engagements.isEmpty) {
      await showDialog<void>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Assign worker'),
              content: const Text('No assignable contractors found.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Assign worker'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final e in engagements)
                  Builder(
                    builder: (context) {
                      final label = controller.availabilityLabelForAssign(
                        contractorId: e.contractorId,
                        shift: shift,
                      );
                      return ListTile(
                        title: Text(e.contractorName ?? e.contractorId),
                        trailing: Text(
                          label,
                          style: TextStyle(
                            color: switch (label) {
                              'Leave' => AppColors.error,
                              'Busy' => AppColors.openSlot,
                              'Outside hours' => AppColors.openSlot,
                              _ => AppColors.success,
                            },
                          ),
                        ),
                        onTap:
                            controller.isSaving.value
                                ? null
                                : () async {
                                  Navigator.pop(ctx);
                                  await controller.assignSelectedShift(
                                    e.contractorId,
                                  );
                                },
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _PublishStrip extends StatelessWidget {
  const _PublishStrip({
    required this.shift,
    required this.participantCount,
    required this.equalSplit,
    required this.isSaving,
    required this.onPublish,
  });

  final ShiftOut shift;
  final int participantCount;
  final bool equalSplit;
  final bool isSaving;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Publish', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '$participantCount participant${participantCount == 1 ? '' : 's'} · '
            '${equalSplit ? 'equal' : 'custom'} · '
            'worker_count:${shift.workerCount}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          AsyncElevatedButton(
            onPressed: onPublish,
            isLoading: isSaving,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Publish shift'),
          ),
        ],
      ),
    );
  }
}

class _WorkerCountEditor extends StatefulWidget {
  const _WorkerCountEditor({
    required this.workerCount,
    required this.requiredSlots,
    required this.enabled,
    required this.onSave,
  });

  final int workerCount;
  final int requiredSlots;
  final bool enabled;
  final Future<void> Function(int workerCount) onSave;

  @override
  State<_WorkerCountEditor> createState() => _WorkerCountEditorState();
}

class _WorkerCountEditorState extends State<_WorkerCountEditor> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.workerCount}');
  }

  @override
  void didUpdateWidget(covariant _WorkerCountEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workerCount != widget.workerCount) {
      _ctrl.text = '${widget.workerCount}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mismatch =
        (int.tryParse(_ctrl.text) ?? widget.workerCount) !=
        widget.requiredSlots;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Workers planned',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed:
                  widget.enabled
                      ? () {
                        final n = int.tryParse(_ctrl.text) ?? 1;
                        widget.onSave(n < 1 ? 1 : n);
                      }
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(72, 48),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
        if (mismatch)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Workers planned differs from roster slots.',
              style: TextStyle(color: AppColors.openSlot),
            ),
          ),
      ],
    );
  }
}

class _ParticipantsSection extends StatelessWidget {
  const _ParticipantsSection({
    required this.shift,
    required this.active,
    required this.canManage,
    required this.isSaving,
    required this.onEdit,
    required this.onRemove,
  });

  final ShiftOut shift;
  final List<ShiftParticipantOut> active;
  final bool canManage;
  final bool isSaving;
  final Future<void> Function() onEdit;
  final Future<void> Function(ShiftParticipantOut participant) onRemove;

  @override
  Widget build(BuildContext context) {
    final isDraft = shift.status == 'draft';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Participants', style: Get.textTheme.titleMedium),
            ),
            if (canManage && isDraft)
              TextButton(
                onPressed: isSaving ? null : onEdit,
                child: const Text('Edit'),
              ),
          ],
        ),
        if (active.isEmpty)
          const Text('No participants yet.'),
        for (final p in active) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            minVerticalPadding: 12,
            title: Text(p.participantName ?? p.participantId),
            subtitle: Text(
              p.allocationValue != null
                  ? '${p.allocationValue!.toStringAsFixed(2)}%'
                  : (p.allocationStrategy ?? 'allocation'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
            trailing:
                canManage
                    ? TextButton(
                      onPressed: isSaving ? null : () => onRemove(p),
                      child: const Text('Remove'),
                    )
                    : null,
          ),
          const Divider(height: 1),
        ],
        for (final p in shift.participants)
          if (p.status != 'active')
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                p.participantName ?? p.participantId,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              subtitle: Text(
                'Removed',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
      ],
    );
  }
}

class _AllocationHistorySection extends StatelessWidget {
  const _AllocationHistorySection({required this.controller});
  final StaffVisitsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final expanded = controller.allocationHistoryExpanded.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Allocation history',
              style: Get.textTheme.titleMedium,
            ),
            trailing: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () async {
              final next = !expanded;
              controller.allocationHistoryExpanded.value = next;
              if (next) await controller.loadAllocationHistory();
            },
          ),
          if (expanded) ...[
            if (controller.isLoadingAllocationHistory.value)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.allocationHistory.isEmpty)
              const Text(
                'No allocation changes yet.',
                style: TextStyle(color: AppColors.textMuted),
              )
            else
              for (final entry in controller.allocationHistory)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(entry.changeType),
                  subtitle: Text(
                    '${entry.changeReason}\n${_fmt(entry.createdAt)}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
          ],
        ],
      );
    });
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
