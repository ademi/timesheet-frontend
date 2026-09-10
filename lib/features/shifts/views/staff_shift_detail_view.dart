import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/widgets/allocation_audit_section.dart';
import '../../shifts/widgets/shift_participants_section.dart';
import '../../shifts/widgets/shift_publish_strip.dart';
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
    unawaited(c.loadClientsForPicker());
    unawaited(c.loadAllocationChanges());
    unawaited(c.refreshSelectedShift());
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffVisitsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(
          () => Text(controller.selectedShift.value?.jobTitle ?? 'Shift'),
        ),
        actions: [
          Obx(() {
            final shift = controller.selectedShift.value;
            if (!controller.canManage ||
                shift == null ||
                shift.status == 'cancelled') {
              return const SizedBox.shrink();
            }
            return PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'cancel') {
                  unawaited(controller.cancelSelectedShift());
                }
              },
              itemBuilder:
                  (_) => const [
                    PopupMenuItem(value: 'cancel', child: Text('Cancel shift')),
                  ],
            );
          }),
        ],
      ),
      body: Obx(() {
        final shift = controller.selectedShift.value;
        final err = controller.errorMessage.value;
        if (shift == null) {
          if (controller.isRefreshing.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text('Shift not loaded.'));
        }
        final clients = [
          for (final client in controller.clientsForPicker)
            (id: client.id, name: client.fullName),
        ];
        final participantNames = controller.participantNameMap;
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
                        ShiftPublishStrip(
                          shift: shift,
                          canManage: controller.canManage,
                          canPublish: controller.canPublishSelected,
                          isSaving: controller.isSaving.value,
                          showDraftCapacityHint:
                              controller.showDraftCapacityHint.value,
                          onPublish: controller.publishSelectedShift,
                          onDismissHint:
                              () =>
                                  controller.showDraftCapacityHint.value =
                                      false,
                        ),
                        const Divider(height: 32),
                        ShiftParticipantsSection(
                          shift: shift,
                          clients: clients,
                          participantNames: participantNames,
                          canManage: controller.canManage,
                          isSaving: controller.isSaving.value,
                          onAdd: (request) async {
                            await controller.addParticipantToSelected(request);
                            await controller.loadAllocationChanges();
                          },
                          onUpdate: (participant, request) async {
                            await controller.updateAllocationOnSelected(
                              participantId: participant.participantId,
                              body: request,
                            );
                            await controller.loadAllocationChanges();
                          },
                          onReplaceTimeBased: (participant, request) async {
                            await controller
                                .replaceTimeBasedParticipantOnSelected(
                                  participant: participant,
                                  replacement: request,
                                );
                            await controller.loadAllocationChanges();
                          },
                          onRemove: (participant, reason) async {
                            await controller.removeParticipantFromSelected(
                              participantId: participant.participantId,
                              reason: reason,
                            );
                            await controller.loadAllocationChanges();
                          },
                        ),
                        const Divider(height: 32),
                        Text('When & where', style: Get.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Start: ${_fmt(shift.scheduledStart)}'),
                        Text('End: ${_fmt(shift.scheduledEnd)}'),
                        if (shift.locationLabel?.isNotEmpty == true)
                          Text('Location: ${shift.locationLabel}')
                        else
                          const Text('Location: Not set'),
                        const Divider(height: 32),
                        Text('Workers', style: Get.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ShiftSlotPips(
                          requiredSlots: shift.requiredSlots,
                          filledSlots: shift.filledSlots,
                        ),
                        Text(
                          '${shift.filledSlots} of ${shift.requiredSlots} filled · '
                          '${shift.openSlots} open',
                        ),
                        if (shift.assignments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('No workers assigned yet.'),
                          ),
                        for (final assignment in shift.assignments)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(assignment.contractorName),
                            subtitle: Text(
                              '${assignment.source} · ${assignment.status}'
                              '${assignment.visitStatus != null ? ' · ${assignment.visitStatus}' : ''}',
                            ),
                            trailing:
                                controller.canManage &&
                                        assignment.status == 'active'
                                    ? TextButton(
                                      onPressed:
                                          controller.isSaving.value
                                              ? null
                                              : () =>
                                                  controller.releaseAssignment(
                                                    shiftId: shift.id,
                                                    contractorId:
                                                        assignment.contractorId,
                                                    workerName:
                                                        assignment
                                                            .contractorName,
                                                  ),
                                      child: const Text('Release'),
                                    )
                                    : const Icon(Icons.chevron_right),
                            onTap:
                                () => controller.openAssignmentVisit(
                                  assignment.visitId,
                                ),
                          ),
                        if (controller.canManage &&
                            shift.status != 'cancelled' &&
                            shift.openSlots > 0) ...[
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
                        AllocationAuditSection(
                          changes: controller.allocationChanges,
                          participantNames: participantNames,
                          isLoading:
                              controller.isLoadingAllocationChanges.value,
                        ),
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
