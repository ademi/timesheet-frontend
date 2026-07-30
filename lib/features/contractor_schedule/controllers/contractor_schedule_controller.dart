import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../data/models/schedule_models.dart';
import '../data/repositories/contractor_schedule_repository.dart';

class ContractorScheduleController extends GetxController {
  ContractorScheduleController({
    required ContractorScheduleRepository repository,
    required SessionService session,
  }) : _repository = repository,
       _session = session;

  final ContractorScheduleRepository _repository;
  final SessionService _session;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final leaveValidationMessage = RxnString();

  final rangeStart = DateTime.now().obs;
  final timetableVisits = <TimetableVisitOut>[].obs;
  final availability = <AvailabilityRuleOut>[].obs;
  final leaveItems = <LeaveOut>[].obs;

  /// Editable availability windows, grouped by weekday.
  final draftWindows = List.generate(7, (_) => <AvailabilityWindowDraft>[]).obs;

  final leaveStartCtrl = TextEditingController();
  final leaveEndCtrl = TextEditingController();
  final leaveNotesCtrl = TextEditingController();
  final leaveType = 'annual'.obs;

  bool get canManage =>
      _session.hasPermission(AppPermissions.contractorScheduleManage);

  DateTime get _from {
    final d = rangeStart.value;
    return DateTime(d.year, d.month, d.day).toUtc();
  }

  DateTime get _to => _from.add(const Duration(days: 7));

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    leaveStartCtrl.text = _dateStr(now);
    leaveEndCtrl.text = _dateStr(now.add(const Duration(days: 1)));
    loadAll();
  }

  @override
  void onClose() {
    leaveStartCtrl.dispose();
    leaveEndCtrl.dispose();
    leaveNotesCtrl.dispose();
    super.onClose();
  }

  Future<void> loadAll() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadTimetable();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    }
    try {
      await _loadAvailability();
    } on AppFailure catch (e) {
      errorMessage.value ??= e.message;
    }
    try {
      await _loadLeave();
    } on AppFailure catch (e) {
      errorMessage.value ??= e.message;
    }
    isLoading.value = false;
  }

  void shiftRange(int days) {
    rangeStart.value = rangeStart.value.add(Duration(days: days));
    _reloadTimetableOnly();
  }

  Future<void> _reloadTimetableOnly() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadTimetable();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void openVisitsTab() {
    Get.toNamed(AppRoutes.contractorVisits);
  }

  Future<void> _loadTimetable() async {
    final tt = await _repository.getTimetable(from: _from, to: _to);
    final visits = [...tt.visits]
      ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    timetableVisits.assignAll(visits);
  }

  Future<void> _loadAvailability() async {
    final rules = await _repository.listAvailability();
    availability.assignAll(rules);
    _syncDraftFromRules(rules);
  }

  Future<void> _loadLeave() async {
    leaveItems.assignAll(await _repository.listLeave());
  }

  void _syncDraftFromRules(List<AvailabilityRuleOut> rules) {
    for (var i = 0; i < 7; i++) {
      draftWindows[i] = [];
    }
    for (final r in rules) {
      final d = r.dayOfWeek.clamp(0, 6);
      draftWindows[d].add(
        AvailabilityWindowDraft(
          startTime:
              r.startTime.length >= 5
                  ? r.startTime.substring(0, 5)
                  : r.startTime,
          endTime:
              r.endTime.length >= 5 ? r.endTime.substring(0, 5) : r.endTime,
        ),
      );
    }
    draftWindows.refresh();
  }

  void toggleDay(int day, bool enabled) {
    draftWindows[day] = enabled ? [const AvailabilityWindowDraft()] : [];
    draftWindows.refresh();
  }

  void addWindow(int day) {
    draftWindows[day].add(const AvailabilityWindowDraft());
    draftWindows.refresh();
  }

  void removeWindow(int day, int index) {
    draftWindows[day].removeAt(index);
    draftWindows.refresh();
  }

  void setDraftWindow(int day, int index, {String? start, String? end}) {
    draftWindows[day][index] = draftWindows[day][index].copyWith(
      startTime: start,
      endTime: end,
    );
    draftWindows.refresh();
  }

  Future<void> saveAvailability() async {
    if (!canManage) {
      errorMessage.value = 'Missing contractor.schedule.manage permission.';
      return;
    }
    final rules = <AvailabilityRuleOut>[];
    for (var i = 0; i < 7; i++) {
      for (final window in draftWindows[i]) {
        rules.add(
          AvailabilityRuleOut(
            dayOfWeek: i,
            startTime: window.startTime,
            endTime: window.endTime,
          ),
        );
      }
    }
    for (var i = 0; i < 7; i++) {
      final windows = [...draftWindows[i]]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      for (var j = 1; j < windows.length; j++) {
        if (windows[j].startTime.compareTo(windows[j - 1].endTime) < 0) {
          errorMessage.value = '${dayOfWeekLabels[i]} windows cannot overlap.';
          return;
        }
      }
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final saved = await _repository.putAvailability(rules);
      availability.assignAll(saved);
      _syncDraftFromRules(saved.isEmpty ? rules : saved);
      Get.snackbar(
        'Availability saved',
        'Preferences only — this does not create visits.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> createLeave() async {
    leaveValidationMessage.value = null;
    if (!canManage) {
      errorMessage.value = 'Missing contractor.schedule.manage permission.';
      return;
    }
    final start = leaveStartCtrl.text.trim();
    final end = leaveEndCtrl.text.trim();
    if (start.isEmpty || end.isEmpty) {
      errorMessage.value = 'Start and end dates are required (YYYY-MM-DD).';
      return;
    }
    final endDate = DateTime.tryParse(end);
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);
    if (endDate != null && endDate.isBefore(localToday)) {
      leaveValidationMessage.value =
          'Leave cannot end before today. Choose dates that are still current or in the future.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.createLeave(
        LeaveCreateRequest(
          startDate: start,
          endDate: end,
          leaveType: leaveType.value,
          notes: leaveNotesCtrl.text,
        ),
      );
      leaveNotesCtrl.clear();
      await _loadLeave();
      Get.snackbar(
        'Leave requested',
        'Preferences only — leave does not create or cancel visits.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteLeave(String id) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.deleteLeave(id);
      await _loadLeave();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  static String _dateStr(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}
