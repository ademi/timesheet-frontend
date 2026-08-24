import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/job_models.dart';
import '../utils/recurrence_rrule_builder.dart';
import '../utils/task_title_presets.dart';
import '../utils/time_window_utils.dart';
import 'jobs_controller.dart';

class TaskSupportSlot {
  TaskSupportSlot({this.supportItemCode, this.supportItemName});

  String? supportItemCode;
  String? supportItemName;
}

class RecurrenceRuleFormController extends GetxController {
  final jobs = Get.find<JobsController>();
  final frequency = RecurrenceFrequency.weekly.obs;
  final weekdays = <int>{DateTime.monday}.obs;
  final startDate = DateTime.now().obs;
  final endDate = Rx<DateTime>(
    defaultRecurrenceEndDate(DateTime.now()),
  );
  final selectedContractorId = RxnString();
  final windows =
      <TimeWindow>[const TimeWindow(startTime: '09:00', endTime: '12:00')].obs;
  final taskTitlesCtrl = TextEditingController();
  final taskSupportSlots = <TaskSupportSlot>[].obs;
  final otherTitleCtrl = TextEditingController();
  final showOtherTitleField = false.obs;
  final selectedFormTemplateIds = <String>{}.obs;
  final requiredSlots = 1.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    taskTitlesCtrl.addListener(_syncTaskSupportSlots);
    _syncTaskSupportSlots();
    ever(startDate, (DateTime start) {
      if (endDate.value.isBefore(start)) {
        endDate.value = defaultRecurrenceEndDate(start);
      }
    });
  }

  void _syncTaskSupportSlots() {
    final count = taskTitles.length;
    while (taskSupportSlots.length < count) {
      taskSupportSlots.add(TaskSupportSlot());
    }
    while (taskSupportSlots.length > count) {
      taskSupportSlots.removeLast();
    }
    taskSupportSlots.refresh();
  }

  String? _pairedTaskSupportCode(int index) {
    if (index < 0 || index >= taskSupportSlots.length) return null;
    final slot = taskSupportSlots[index];
    final code = slot.supportItemCode?.trim();
    final name = slot.supportItemName?.trim();
    if (code == null || code.isEmpty || name == null || name.isEmpty) {
      return null;
    }
    return code;
  }

  void setTaskSupportItem({
    required int index,
    required String? supportItemCode,
    required String? supportItemName,
  }) {
    if (index < 0 || index >= taskSupportSlots.length) return;
    taskSupportSlots[index].supportItemCode = supportItemCode;
    taskSupportSlots[index].supportItemName = supportItemName;
    taskSupportSlots.refresh();
  }

  bool get requiresWeekdays =>
      frequency.value == RecurrenceFrequency.weekly ||
      frequency.value == RecurrenceFrequency.fortnightly;

  String get rrule =>
      compileRecurrenceRrule(frequency: frequency.value, weekdays: weekdays);

  List<RecurrencePreviewWindow> get preview {
    // The session currently exposes no tenant timezone. Keep this preview in
    // device-local wall time; the backend expands saved rules in tenant time.
    final result = <RecurrencePreviewWindow>[];
    var date = DateTime(
      startDate.value.year,
      startDate.value.month,
      startDate.value.day,
    );
    final limit = DateTime.now().add(const Duration(days: 90));
    while (result.length < 5 && !date.isAfter(limit)) {
      final matches = !requiresWeekdays || weekdays.contains(date.weekday);
      final fortnight =
          frequency.value != RecurrenceFrequency.fortnightly ||
          date.difference(startDate.value).inDays ~/ 7 % 2 == 0;
      final monthly =
          frequency.value != RecurrenceFrequency.monthly ||
          date.day == startDate.value.day;
      if (!date.isBefore(startDate.value) && matches && fortnight && monthly) {
        for (final window in windows) {
          result.add(
            RecurrencePreviewWindow(
              date: DateTime(date.year, date.month, date.day),
              window: window,
            ),
          );
          if (result.length == 5) break;
        }
      }
      date = date.add(const Duration(days: 1));
    }
    return result;
  }

  void addWindow() {
    if (windows.length < 4) {
      windows.add(const TimeWindow(startTime: '14:00', endTime: '17:00'));
    }
  }

  void removeWindow(int index) {
    if (windows.length > 1) windows.removeAt(index);
  }

  void setWindowStartTime(int index, String startTime) {
    final window = windows[index];
    windows[index] = TimeWindow(
      startTime: startTime,
      endTime: window.endTime,
    );
    _syncWindowError(index);
  }

  void setWindowEndTime(int index, String endTime) {
    final window = windows[index];
    windows[index] = TimeWindow(
      startTime: window.startTime,
      endTime: endTime,
    );
    _syncWindowError(index);
  }

  void _syncWindowError(int index) {
    final window = windows[index];
    final errorMessage = validateVisitWindows([window]);
    if (errorMessage != null) {
      error.value = errorMessage;
    } else if (error.value == endBeforeStartError ||
        error.value == windowsOverlapError) {
      error.value = null;
    }
  }

  void toggleWeekday(int day) {
    weekdays.contains(day) ? weekdays.remove(day) : weekdays.add(day);
  }

  void toggleForm(String id) {
    selectedFormTemplateIds.contains(id)
        ? selectedFormTemplateIds.remove(id)
        : selectedFormTemplateIds.add(id);
  }

  List<String> get taskTitles => parseTaskTitles(taskTitlesCtrl.text);

  void onPresetSelected(String? preset) {
    if (preset == null) return;
    if (preset == taskTitlePresetOther) {
      showOtherTitleField.value = true;
      return;
    }
    appendTaskTitle(preset);
  }

  void appendTaskTitle(String title) {
    taskTitlesCtrl.text = appendTaskTitleLine(taskTitlesCtrl.text, title);
    _syncTaskSupportSlots();
  }

  void appendOtherTitle() {
    appendTaskTitle(otherTitleCtrl.text);
    otherTitleCtrl.clear();
    showOtherTitleField.value = false;
  }

  Future<bool> save() async {
    if (requiresWeekdays && weekdays.isEmpty) {
      error.value = 'Select at least one weekday.';
      return false;
    }
    if (endDate.value.isBefore(startDate.value)) {
      error.value = 'End date must not be before the start date.';
      return false;
    }
    final windowError = validateVisitWindows(windows);
    if (windowError != null) {
      error.value = windowError;
      return false;
    }
    final sorted = windows.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (preview.isEmpty) {
      error.value = 'This rule has no occurrences in the next 90 days.';
      return false;
    }
    error.value = null;
    final titles = taskTitles;
    final template = [
      for (var i = 0; i < titles.length; i++)
        TaskTemplateItem(
          title: titles[i],
          sortOrder: i,
          supportItemCode: _pairedTaskSupportCode(i),
        ),
    ];
    return jobs.createRecurrenceRule(
      RecurrenceRuleCreateRequest(
        contractorId: selectedContractorId.value,
        requiredSlots: requiredSlots.value,
        rrule: rrule,
        dtstart: startDate.value,
        until: recurrenceUntilInstant(endDate.value),
        timeWindows: sorted,
        taskTemplate: template,
        formTemplateIds: selectedFormTemplateIds.toList(),
      ),
    );
  }

  @override
  void onClose() {
    taskTitlesCtrl.dispose();
    otherTitleCtrl.dispose();
    super.onClose();
  }
}

class RecurrencePreviewWindow {
  const RecurrencePreviewWindow({required this.date, required this.window});

  final DateTime date;
  final TimeWindow window;
}
