import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/contractor_schedule_controller.dart';
import '../data/models/schedule_models.dart';

String _fmtDay(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

String _fmtTime(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _fmtAgendaDay(DateTime day) {
  final wd = _weekdayShort[(day.weekday - 1) % 7];
  return '$wd ${day.day}/${day.month}';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class ContractorScheduleView extends GetView<ContractorScheduleController> {
  const ContractorScheduleView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: shellAppBarActions(),
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
      final end = DateTime(start.year, start.month, start.day)
          .add(const Duration(days: 6));
      final today = DateTime.now();
      final days = controller.agendaDays();

      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: 8),
                for (final entry in days) ...[
                  _AgendaDayHeader(
                    label: _fmtAgendaDay(entry.day),
                    isToday: _isSameDay(entry.day, today),
                    visitCount: entry.visits.length,
                  ),
                  if (entry.visits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Text(
                        'No visits',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    )
                  else
                    for (final v in entry.visits)
                      _AgendaVisitTile(
                        visit: v,
                        onTap: () => controller.openVisit(v),
                      ),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: controller.openVisitsTab,
                  child: const Text('Open Visits to check in'),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _AgendaDayHeader extends StatelessWidget {
  const _AgendaDayHeader({
    required this.label,
    required this.isToday,
    required this.visitCount,
  });

  final String label;
  final bool isToday;
  final int visitCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isToday ? AppColors.primary : AppColors.textDark,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (visitCount > 0)
            Text(
              '$visitCount',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _AgendaVisitTile extends StatelessWidget {
  const _AgendaVisitTile({required this.visit, required this.onTap});

  final TimetableVisitOut visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = visit.jobTitle ?? visit.tenantName ?? 'Visit';
    final time =
        '${_fmtTime(visit.scheduledStart)} – ${_fmtTime(visit.scheduledEnd)}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$time · ${visit.status}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
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
          PageContent(
            width: PageContentWidth.narrow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  AsyncElevatedButton(
                    onPressed: controller.saveAvailability,
                    isLoading: controller.isSaving.value,
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
            ),
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
          PageContent(
            width: PageContentWidth.narrow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  AsyncElevatedButton(
                    onPressed: controller.createLeave,
                    isLoading: controller.isSaving.value,
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
                              ? AsyncIconButton(
                                tooltip: 'Delete',
                                onPressed: () => controller.deleteLeave(leave.id),
                                isLoading: controller.isSaving.value,
                                icon: const Icon(Icons.delete_outline),
                              )
                              : null,
                    ),
                  ),
              ],
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
