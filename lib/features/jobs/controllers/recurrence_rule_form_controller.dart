import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/job_models.dart';
import '../utils/recurrence_rrule_builder.dart';
import 'jobs_controller.dart';

class RecurrenceRuleFormController extends GetxController {
  final jobs = Get.find<JobsController>();
  final frequency = RecurrenceFrequency.weekly.obs;
  final weekdays = <int>{DateTime.monday}.obs;
  final startDate = DateTime.now().obs;
  final endDate = Rxn<DateTime>();
  final selectedContractorId = RxnString();
  final windows =
      <TimeWindow>[const TimeWindow(startTime: '09:00', endTime: '12:00')].obs;
  final taskTitlesCtrl = TextEditingController();
  final selectedFormTemplateIds = <String>{}.obs;
  final error = RxnString();

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

  void toggleWeekday(int day) {
    weekdays.contains(day) ? weekdays.remove(day) : weekdays.add(day);
  }

  void toggleForm(String id) {
    selectedFormTemplateIds.contains(id)
        ? selectedFormTemplateIds.remove(id)
        : selectedFormTemplateIds.add(id);
  }

  Future<bool> save() async {
    if (selectedContractorId.value == null) {
      error.value = 'Select a contractor.';
      return false;
    }
    if (requiresWeekdays && weekdays.isEmpty) {
      error.value = 'Select at least one weekday.';
      return false;
    }
    if (endDate.value != null && endDate.value!.isBefore(startDate.value)) {
      error.value = 'End date must not be before the start date.';
      return false;
    }
    final sorted =
        windows.toList()..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (sorted.any(
          (window) => window.endTime.compareTo(window.startTime) <= 0,
        ) ||
        sorted
            .skip(1)
            .toList()
            .asMap()
            .entries
            .any(
              (entry) =>
                  entry.value.startTime.compareTo(sorted[entry.key].endTime) <
                  0,
            )) {
      error.value = 'Visit windows must be ordered and not overlap.';
      return false;
    }
    if (preview.isEmpty) {
      error.value = 'This rule has no occurrences in the next 90 days.';
      return false;
    }
    error.value = null;
    return jobs.createRecurrenceRule(
      RecurrenceRuleCreateRequest(
        contractorId: selectedContractorId.value!,
        rrule: rrule,
        dtstart: startDate.value,
        until: endDate.value?.add(const Duration(days: 1, microseconds: -1)),
        timeWindows: sorted,
        taskTitles:
            taskTitlesCtrl.text
                .split('\n')
                .map((title) => title.trim())
                .where((title) => title.isNotEmpty)
                .toList(),
        formTemplateIds: selectedFormTemplateIds.toList(),
      ),
    );
  }

  @override
  void onClose() {
    taskTitlesCtrl.dispose();
    super.onClose();
  }
}

class RecurrencePreviewWindow {
  const RecurrencePreviewWindow({required this.date, required this.window});

  final DateTime date;
  final TimeWindow window;
}
