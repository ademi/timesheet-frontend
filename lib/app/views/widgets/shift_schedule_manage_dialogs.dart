import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/scheduling/board_employee.dart';
import '../../data/models/scheduling/employee_schedule_models.dart';
import '../../data/models/scheduling/schedule_template.dart';
import '../../themes/app_colors.dart';
import 'shift_schedule_utils.dart';

const schedulingLeaveTypes = <String, String>{
  'annual': 'Annual',
  'sick': 'Sick',
  'unpaid': 'Unpaid',
  'other': 'Other',
};

String fmtSchedulingDateDisplay(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

Future<String?> showShiftTemplatePicker({
  required List<ScheduleTemplate> templates,
}) {
  if (templates.isEmpty) {
    Get.snackbar(
      'No templates',
      'No shift templates are available for this branch.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
    return Future.value(null);
  }

  return showModalBottomSheet<String>(
    context: Get.context!,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select shift template',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final start = formatTimeOfDay(template.shiftStart);
                    final end = formatTimeOfDay(template.shiftEnd);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(template.name),
                      subtitle: Text('$start – $end'),
                      onTap: () => Navigator.pop(context, template.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showSchedulingConfirmDialog({
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final result = await Get.dialog<bool>(
    AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Get.back(result: true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

Future<({DateTime start, DateTime end, String leaveType})?> showLeaveDialog({
  required DateTime initialDate,
}) async {
  var start = initialDate;
  var end = initialDate;
  var leaveType = 'annual';

  return showDialog<({DateTime start, DateTime end, String leaveType})>(
    context: Get.context!,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Mark leave'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start date'),
                    subtitle: Text(fmtSchedulingDateDisplay(start)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          start = picked;
                          if (end.isBefore(start)) end = picked;
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End date'),
                    subtitle: Text(fmtSchedulingDateDisplay(end)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: end,
                        firstDate: start,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => end = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: leaveType,
                    decoration: const InputDecoration(
                      labelText: 'Leave type',
                      border: OutlineInputBorder(),
                    ),
                    items: schedulingLeaveTypes.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => leaveType = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  (start: start, end: end, leaveType: leaveType),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<({String templateId, DateTime startDate, DateTime? endDate})?>
    showRecurringScheduleDialog({
  required List<ScheduleTemplate> templates,
  DateTime? initialStart,
}) async {
  if (templates.isEmpty) return null;

  var templateId = templates.first.id;
  var startDate = initialStart ?? DateTime.now();
  DateTime? endDate;

  return showDialog<({String templateId, DateTime startDate, DateTime? endDate})>(
    context: Get.context!,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Recurring schedule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: templateId,
                    decoration: const InputDecoration(
                      labelText: 'Shift template',
                      border: OutlineInputBorder(),
                    ),
                    items: templates
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => templateId = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start date'),
                    subtitle: Text(fmtSchedulingDateDisplay(startDate)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => startDate = picked);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End date (optional)'),
                    subtitle: Text(
                      endDate == null
                          ? 'No end date'
                          : fmtSchedulingDateDisplay(endDate!),
                    ),
                    trailing: endDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => endDate = null),
                          )
                        : null,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? startDate,
                        firstDate: startDate,
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => endDate = picked);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  (
                    templateId: templateId,
                    startDate: startDate,
                    endDate: endDate,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

class RecurringSchedulesSheet extends StatelessWidget {
  const RecurringSchedulesSheet({
    super.key,
    required this.employee,
    required this.schedules,
    required this.templates,
    required this.onCreate,
    required this.onDelete,
  });

  final BoardEmployee employee;
  final List<EmployeeScheduleOut> schedules;
  final List<ScheduleTemplate> templates;
  final VoidCallback onCreate;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recurring schedules · ${employee.fullName}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 12),
            if (schedules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No recurring schedules for this employee.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: schedules.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    final templateName = templates
                            .where((t) => t.id == schedule.templateId)
                            .map((t) => t.name)
                            .firstOrNull ??
                        'Template';
                    final endLabel = schedule.endDate == null
                        ? 'ongoing'
                        : fmtSchedulingDateDisplay(schedule.endDate!);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(templateName),
                      subtitle: Text(
                        '${fmtSchedulingDateDisplay(schedule.startDate)} – $endLabel',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: AppColors.error,
                        onPressed: () => onDelete(schedule.id),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add recurring schedule'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
