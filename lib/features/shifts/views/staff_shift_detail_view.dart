import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
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
  String? _assignContractorId;

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
        return Column(
          children: [
            if (controller.isRefreshing.value)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (err != null) ...[
                    _ErrorBox(err),
                    const SizedBox(height: 12),
                  ],
                  Text(shift.jobTitle, style: Get.textTheme.titleMedium),
                  if (shift.clientName?.isNotEmpty == true)
                    Text('Client: ${shift.clientName}'),
                  const SizedBox(height: 4),
                  Text('Status: ${shift.status}'),
                  Text('Start: ${_fmt(shift.scheduledStart)}'),
                  Text('End: ${_fmt(shift.scheduledEnd)}'),
                  if (shift.locationLabel?.isNotEmpty == true)
                    Text('Location: ${shift.locationLabel}'),
                  const SizedBox(height: 8),
                  ShiftSlotPips(
                    requiredSlots: shift.requiredSlots,
                    filledSlots: shift.filledSlots,
                  ),
                  Text(
                    '${shift.filledSlots} of ${shift.requiredSlots} filled · '
                    '${shift.openSlots} open',
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
                                        : () => controller.releaseAssignment(
                                          shiftId: shift.id,
                                          contractorId: a.contractorId,
                                          workerName: a.contractorName,
                                        ),
                                child: const Text('Release'),
                              )
                              : const Icon(Icons.chevron_right),
                      onTap: () => controller.openAssignmentVisit(a.visitId),
                    ),
                  if (controller.canManage &&
                      shift.status != 'cancelled' &&
                      shift.openSlots > 0) ...[
                    const Divider(height: 32),
                    DropdownButtonFormField<String>(
                      value: _assignContractorId,
                      items: [
                        for (final e in controller.assignableEngagements)
                          DropdownMenuItem(
                            value: e.contractorId,
                            child: Text(
                              e.contractorName ?? e.contractorId,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _assignContractorId = v),
                      decoration: const InputDecoration(
                        labelText: 'Assign contractor',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AsyncElevatedButton(
                      onPressed:
                          _assignContractorId == null
                              ? null
                              : () => controller.assignSelectedShift(
                                _assignContractorId!,
                              ),
                      isLoading: controller.isSaving.value,
                      child: const Text('Assign'),
                    ),
                  ],
                  if (controller.canManage) ...[
                    const Divider(height: 32),
                    if (shift.status == 'draft')
                      AsyncElevatedButton(
                        onPressed: controller.publishSelectedShift,
                        isLoading: controller.isSaving.value,
                        child: const Text('Publish shift'),
                      ),
                    if (shift.status == 'published')
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
        );
      }),
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
