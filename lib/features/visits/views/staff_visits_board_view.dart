import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../jobs/data/models/job_models.dart';
import '../../shifts/data/models/shift_models.dart';
import '../controllers/staff_visits_controller.dart';
import '../roster/roster_grid_model.dart';
import '../roster/roster_grid_view.dart';

/// DropdownButton asserts if [value] is set but not present exactly once.
String? _jobDropdownValue(String? filter, Iterable<JobOut> jobs) {
  if (filter == null || filter.isEmpty) return null;
  for (final job in jobs) {
    if (job.id == filter) return filter;
  }
  return null;
}

List<DropdownMenuItem<String>> _jobDropdownItems(
  Iterable<JobOut> jobs, {
  bool includeAll = true,
}) {
  final seen = <String>{};
  return [
    if (includeAll)
      const DropdownMenuItem(value: null, child: Text('All jobs')),
    for (final job in jobs)
      if (seen.add(job.id))
        DropdownMenuItem(
          value: job.id,
          child: Text(job.title, overflow: TextOverflow.ellipsis),
        ),
  ];
}

String? _clientDropdownValue(
  String? filter,
  Iterable<({String id, String name})> clients,
) {
  if (filter == null || filter.isEmpty) return null;
  for (final c in clients) {
    if (c.id == filter) return filter;
  }
  return null;
}

List<DropdownMenuItem<String>> _clientDropdownItems(
  Iterable<({String id, String name})> clients,
) {
  return [
    const DropdownMenuItem(value: null, child: Text('All clients')),
    for (final c in clients)
      DropdownMenuItem(
        value: c.id,
        child: Text(c.name, overflow: TextOverflow.ellipsis),
      ),
  ];
}

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
        final overlayWarn = controller.overlayWarning.value;
        final start = controller.rangeStart.value;
        final end = start.add(const Duration(days: 6));
        final clients = controller.clientFilterOptions;
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
                  if (controller.isFillingHorizon.value)
                    const LinearProgressIndicator(minHeight: 2),
                  DropdownButtonFormField<String>(
                    value: _clientDropdownValue(
                      controller.clientIdFilter.value,
                      clients,
                    ),
                    isExpanded: true,
                    items: _clientDropdownItems(clients),
                    onChanged: controller.setClientFilter,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _jobDropdownValue(
                      controller.jobIdFilter.value,
                      controller.jobs,
                    ),
                    isExpanded: true,
                    items: _jobDropdownItems(controller.jobs),
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
            if (overlayWarn != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _WarningBox(overlayWarn),
              ),
            if (err != null)
              Padding(padding: const EdgeInsets.all(16), child: _ErrorBox(err)),
            Expanded(
              child:
                  controller.isLoading.value &&
                          controller.shifts.isEmpty &&
                          controller.overlay.value == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: controller.load,
                        child: RosterGridView(
                          grid: controller.grid,
                          onTileTap: controller.openShiftFromTile,
                          onTileLongPress:
                              controller.canManage
                                  ? (tile) => _showTileActionSheet(
                                    context,
                                    controller,
                                    tile,
                                  )
                                  : null,
                        ),
                      ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _showTileActionSheet(
    BuildContext context,
    StaffVisitsController controller,
    RosterTile tile,
  ) async {
    ShiftOut? shift;
    for (final s in controller.shifts) {
      if (s.id == tile.shiftId) {
        shift = s;
        break;
      }
    }
    if (shift == null) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  tile.clientName.isEmpty ? 'Shift' : tile.clientName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_fmt(tile.start)} – ${_fmt(tile.end)}',
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancel this one'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  final ok = await _confirmCancelOccurrence(context);
                  if (!ok || !context.mounted) return;
                  await controller.cancelThisOccurrence(shift!.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy to…'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  await _showCopyTileDialog(context, controller, shift!);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_repeat_outlined),
                title: const Text('This and future…'),
                subtitle: const Text('Next update'),
                enabled: false,
              ),
              if (tile.assignmentContractorId != null &&
                  tile.assignmentContractorId!.isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Release worker'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    await _releaseFromTile(context, controller, tile);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmCancelOccurrence(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Cancel this one?'),
            content: const Text(
              'This shift will be cancelled. Assigned visits must be handled separately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cancel shift'),
              ),
            ],
          ),
    );
    return result == true;
  }

  Future<void> _showCopyTileDialog(
    BuildContext context,
    StaffVisitsController controller,
    ShiftOut source,
  ) async {
    final duration = source.scheduledEnd.difference(source.scheduledStart);
    var start = source.scheduledStart.toLocal();
    var end = start.add(duration);
    String? dialogError;
    var isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Copy to…'),
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
                            end = start.add(duration);
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
                            await controller.copyTile(
                              source: source,
                              start: start,
                              end: end,
                            );
                            if (!ctx.mounted) return;
                            if (controller.errorMessage.value == null) {
                              Navigator.pop(ctx);
                              return;
                            }
                            setState(() {
                              isSubmitting = false;
                              dialogError =
                                  controller.errorMessage.value ??
                                  'Could not copy shift.';
                            });
                          },
                  child:
                      isSubmitting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Copy'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _releaseFromTile(
    BuildContext context,
    StaffVisitsController controller,
    RosterTile tile,
  ) async {
    final contractorId = tile.assignmentContractorId;
    if (contractorId == null || contractorId.isEmpty) return;
    String workerName = 'Worker';
    for (final e in controller.engagements) {
      if (e.contractorId == contractorId) {
        final n = e.contractorName?.trim();
        if (n != null && n.isNotEmpty) workerName = n;
        break;
      }
    }
    await controller.releaseAssignment(
      shiftId: tile.shiftId,
      contractorId: contractorId,
      workerName: workerName,
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
                      value: _jobDropdownValue(jobId, controller.jobs),
                      isExpanded: true,
                      items: _jobDropdownItems(
                        controller.jobs,
                        includeAll: false,
                      ),
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

class _WarningBox extends StatelessWidget {
  const _WarningBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.openSlot)),
    );
  }
}
