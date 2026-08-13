import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../shifts/widgets/shift_slot_pips.dart';
import '../../../shared/utils/roster_time_format.dart';
import '../controllers/staff_visits_controller.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

String _fmtDay(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

class StaffVisitsBoardView extends StatefulWidget {
  const StaffVisitsBoardView({super.key});

  @override
  State<StaffVisitsBoardView> createState() => _StaffVisitsBoardViewState();
}

class _StaffVisitsBoardViewState extends State<StaffVisitsBoardView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<StaffVisitsController>();
    c.applyRouteArgs();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await c.ensureBoardLoaded();
      if (!mounted) return;
      if (c.consumePendingCreateShift()) {
        await _showCreateShiftDialog(context, c);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffVisitsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Roster'),
        actions: shellAppBarActions(),
      ),
      floatingActionButton:
          controller.canManage
              ? FloatingActionButton(
                onPressed: () => _showCreateShiftDialog(context, controller),
                child: const Icon(Icons.add),
              )
              : null,
      body: Obx(() {
        final err = controller.errorMessage.value;
        final start = controller.rangeStart.value;
        final end = start.add(const Duration(days: 6));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => controller.shiftRange(-7),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${_fmtDay(start)} – ${_fmtDay(end)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => controller.shiftRange(7),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  DropdownButtonFormField<String>(
                    value:
                        controller.jobIdFilter.value.isEmpty
                            ? null
                            : controller.jobIdFilter.value,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All jobs'),
                      ),
                      for (final job in controller.jobs)
                        DropdownMenuItem(
                          value: job.id,
                          child: Text(
                            job.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: controller.setJobFilter,
                    decoration: const InputDecoration(
                      labelText: 'Job',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value:
                        controller.statusFilter.value.isEmpty
                            ? null
                            : controller.statusFilter.value,
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(value: 'draft', child: Text('Unpublished')),
                      DropdownMenuItem(
                        value: 'published',
                        child: Text('Live'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
                      ),
                    ],
                    onChanged: controller.setStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(padding: const EdgeInsets.all(16), child: _ErrorBox(err)),
            Expanded(
              child:
                  controller.isLoading.value && controller.shifts.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: controller.load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              controller.shifts.isEmpty
                                  ? 1
                                  : controller.shifts.length,
                          itemBuilder: (context, i) {
                            if (controller.shifts.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Text('No shifts this week.'),
                              );
                            }
                            final shift = controller.shifts[i];
                            final hasOpenHole =
                                shift.status == 'published' &&
                                shift.openSlots > 0;
                            final isDraft = shift.status == 'draft';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color:
                                  hasOpenHole
                                      ? AppColors.openSlotBackground
                                      : null,
                              child: ListTile(
                                title: Text(
                                  shift.jobTitle,
                                  style: TextStyle(
                                    color:
                                        isDraft ? AppColors.slate400 : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${formatRosterStamp(shift.scheduledStart)} · ${shift.status}'
                                      '${shift.clientName != null ? ' · ${shift.clientName}' : ''}',
                                      style: TextStyle(
                                        color:
                                            isDraft
                                                ? AppColors.slate400
                                                : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ShiftSlotPips(
                                      requiredSlots: shift.requiredSlots,
                                      filledSlots: shift.filledSlots,
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => controller.openShiftDetail(shift),
                              ),
                            );
                          },
                        ),
                      ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showCreateShiftDialog(
    BuildContext context,
    StaffVisitsController controller,
  ) async {
    String? jobId =
        controller.jobIdFilter.value.isEmpty
            ? null
            : controller.jobIdFilter.value;
    var start = DateTime.now().add(const Duration(hours: 1));
    var end = start.add(const Duration(hours: 2));
    var slots = 1;
    var publish = true;
    String? dialogError;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Create shift'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dialogError != null) ...[
                      Text(
                        dialogError!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: jobId,
                      isExpanded: true,
                      items: [
                        for (final job in controller.jobs)
                          DropdownMenuItem(
                            value: job.id,
                            child: Text(
                              job.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => jobId = v),
                      decoration: const InputDecoration(
                        labelText: 'Job',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start'),
                      subtitle: Text(_fmt(start)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: start,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(start),
                        );
                        if (time == null) return;
                        setState(() {
                          start = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          if (!end.isAfter(start)) {
                            end = start.add(const Duration(hours: 1));
                          }
                        });
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End'),
                      subtitle: Text(_fmt(end)),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: end,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (date == null) return;
                        if (!ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(end),
                        );
                        if (time == null) return;
                        setState(() {
                          end = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: slots,
                      items: [
                        for (var n = 1; n <= 8; n++)
                          DropdownMenuItem(value: n, child: Text('$n')),
                      ],
                      onChanged: (v) => setState(() => slots = v ?? 1),
                      decoration: const InputDecoration(
                        labelText: 'Required workers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Publish immediately'),
                      value: publish,
                      onChanged: (v) => setState(() => publish = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      isSubmitting
                          ? null
                          : () async {
                            if (jobId == null) {
                              setState(() => dialogError = 'Select a job.');
                              return;
                            }
                            if (!end.isAfter(start)) {
                              setState(
                                () => dialogError = 'End must be after start.',
                              );
                              return;
                            }
                            setState(() {
                              isSubmitting = true;
                              dialogError = null;
                            });
                            final ok = await controller.createShift(
                              jobId: jobId!,
                              start: start,
                              end: end,
                              requiredSlots: slots,
                              publish: publish,
                            );
                            if (!ctx.mounted) return;
                            if (ok) {
                              Navigator.pop(ctx);
                              return;
                            }
                            setState(() {
                              isSubmitting = false;
                              dialogError =
                                  controller.errorMessage.value ??
                                  'Could not create shift.';
                            });
                          },
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Create'),
                ),
              ],
            );
          },
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
