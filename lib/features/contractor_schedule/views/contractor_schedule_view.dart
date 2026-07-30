import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/contractor_schedule_controller.dart';
import '../data/models/schedule_models.dart';

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

class ContractorScheduleView extends GetView<ContractorScheduleController> {
  const ContractorScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final tab = controller.tabIndex.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PreferencesBanner(),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBox(err),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Timetable'),
                    selected: tab == 0,
                    onSelected: (_) => controller.tabIndex.value = 0,
                  ),
                  ChoiceChip(
                    label: const Text('Availability'),
                    selected: tab == 1,
                    onSelected: (_) => controller.tabIndex.value = 1,
                  ),
                  ChoiceChip(
                    label: const Text('Leave'),
                    selected: tab == 2,
                    onSelected: (_) => controller.tabIndex.value = 2,
                  ),
                ],
              ),
            ),
            Expanded(
              child:
                  controller.isLoading.value &&
                          controller.timetableVisits.isEmpty &&
                          tab == 0
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: controller.loadAll,
                        child:
                            tab == 0
                                ? _TimetableTab(controller: controller)
                                : tab == 1
                                ? _AvailabilityTab(controller: controller)
                                : _LeaveTab(controller: controller),
                      ),
            ),
          ],
        );
      }),
    );
  }
}

class _PreferencesBanner extends StatelessWidget {
  const _PreferencesBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Schedule preferences only — availability and leave do not create '
        'or cancel visits. Assigned visits appear on the Timetable and Visits tabs.',
        style: TextStyle(fontSize: 13),
      ),
    );
  }
}

class _TimetableTab extends StatelessWidget {
  const _TimetableTab({required this.controller});
  final ContractorScheduleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final start = controller.rangeStart.value;
      final end = start.add(const Duration(days: 6));
      return ListView(
        padding: const EdgeInsets.all(16),
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
          if (controller.timetableVisits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No visits in this week.'),
            ),
          for (final v in controller.timetableVisits)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(v.tenantName ?? 'Visit'),
                subtitle: Text(
                  '${_fmt(v.scheduledStart)} → ${_fmt(v.scheduledEnd)}\n'
                  '${v.status} · job ${v.jobId}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: controller.openVisitsTab,
              ),
            ),
          TextButton(
            onPressed: controller.openVisitsTab,
            child: const Text('Open Visits to check in'),
          ),
        ],
      );
    });
  }
}

class _AvailabilityTab extends StatelessWidget {
  const _AvailabilityTab({required this.controller});
  final ContractorScheduleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Set weekly windows you prefer to work. Saving overwrites prior rules.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 7; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dayOfWeekLabels[i]),
                      value: controller.draftWindows[i].isNotEmpty,
                      onChanged:
                          controller.canManage
                              ? (v) => controller.toggleDay(i, v)
                              : null,
                    ),
                    for (var j = 0; j < controller.draftWindows[i].length; j++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    controller.draftWindows[i][j].startTime,
                                decoration: const InputDecoration(
                                  labelText: 'Start (HH:MM)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged:
                                    (v) => controller.setDraftWindow(
                                      i,
                                      j,
                                      start: v,
                                    ),
                                enabled: controller.canManage,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue:
                                    controller.draftWindows[i][j].endTime,
                                decoration: const InputDecoration(
                                  labelText: 'End (HH:MM)',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged:
                                    (v) =>
                                        controller.setDraftWindow(i, j, end: v),
                                enabled: controller.canManage,
                              ),
                            ),
                            if (controller.canManage)
                              IconButton(
                                tooltip: 'Remove window',
                                onPressed: () => controller.removeWindow(i, j),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                          ],
                        ),
                      ),
                    if (controller.draftWindows[i].isNotEmpty &&
                        controller.canManage)
                      TextButton.icon(
                        onPressed: () => controller.addWindow(i),
                        icon: const Icon(Icons.add),
                        label: const Text('Add window'),
                      ),
                  ],
                ),
              ),
            ),
          if (controller.canManage)
            ElevatedButton(
              onPressed:
                  controller.isSaving.value
                      ? null
                      : controller.saveAvailability,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Save availability'),
            )
          else
            const Text(
              'Read-only — missing contractor.schedule.manage.',
              style: TextStyle(fontSize: 12),
            ),
        ],
      );
    });
  }
}

class _LeaveTab extends StatelessWidget {
  const _LeaveTab({required this.controller});
  final ContractorScheduleController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Leave is a preference signal only — it does not cancel assigned visits.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (controller.canManage) ...[
            TextField(
              controller: controller.leaveStartCtrl,
              decoration: const InputDecoration(
                labelText: 'Start date (YYYY-MM-DD) *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.leaveEndCtrl,
              decoration: const InputDecoration(
                labelText: 'End date (YYYY-MM-DD) *',
                border: OutlineInputBorder(),
              ),
            ),
            if (controller.leaveValidationMessage.value != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  controller.leaveValidationMessage.value!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: controller.leaveType.value,
              items: [
                for (final t in leaveTypeOptions)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) {
                if (v != null) controller.leaveType.value = v;
              },
              decoration: const InputDecoration(
                labelText: 'Leave type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.leaveNotesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed:
                  controller.isSaving.value ? null : controller.createLeave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Add leave'),
            ),
            const Divider(height: 32),
          ],
          if (controller.leaveItems.isEmpty) const Text('No leave recorded.'),
          for (final leave in controller.leaveItems)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  '${leave.leaveType}: ${leave.startDate} → ${leave.endDate}',
                ),
                subtitle: leave.notes != null ? Text(leave.notes!) : null,
                trailing:
                    controller.canManage
                        ? IconButton(
                          tooltip: 'Delete',
                          onPressed:
                              controller.isSaving.value
                                  ? null
                                  : () => controller.deleteLeave(leave.id),
                          icon: const Icon(Icons.delete_outline),
                        )
                        : null,
              ),
            ),
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
