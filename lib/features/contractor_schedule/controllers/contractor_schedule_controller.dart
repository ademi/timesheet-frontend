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
  })  : _repository = repository,
        _session = session;

  final ContractorScheduleRepository _repository;
  final SessionService _session;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final rangeStart = DateTime.now().obs;
  final timetableVisits = <TimetableVisitOut>[].obs;
  final availability = <AvailabilityRuleOut>[].obs;
  final leaveItems = <LeaveOut>[].obs;

  /// Editable draft for availability PUT (day toggles + times).
  final draftEnabled = <bool>[false, false, false, false, false, false, false].obs;
  final draftStart = <String>['09:00', '09:00', '09:00', '09:00', '09:00', '09:00', '09:00'].obs;
  final draftEnd = <String>['17:00', '17:00', '17:00', '17:00', '17:00', '17:00', '17:00'].obs;

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
      draftEnabled[i] = false;
      draftStart[i] = '09:00';
      draftEnd[i] = '17:00';
    }
    for (final r in rules) {
      final d = r.dayOfWeek.clamp(0, 6);
      draftEnabled[d] = true;
      draftStart[d] =
          r.startTime.length >= 5 ? r.startTime.substring(0, 5) : r.startTime;
      draftEnd[d] =
          r.endTime.length >= 5 ? r.endTime.substring(0, 5) : r.endTime;
    }
    draftEnabled.refresh();
    draftStart.refresh();
    draftEnd.refresh();
  }

  void toggleDay(int day, bool enabled) {
    draftEnabled[day] = enabled;
    draftEnabled.refresh();
  }

  void setDraftStart(int day, String value) {
    draftStart[day] = value;
    draftStart.refresh();
  }

  void setDraftEnd(int day, String value) {
    draftEnd[day] = value;
    draftEnd.refresh();
  }

  Future<void> saveAvailability() async {
    if (!canManage) {
      errorMessage.value = 'Missing contractor.schedule.manage permission.';
      return;
    }
    final rules = <AvailabilityRuleOut>[];
    for (var i = 0; i < 7; i++) {
      if (!draftEnabled[i]) continue;
      rules.add(
        AvailabilityRuleOut(
          dayOfWeek: i,
          startTime: draftStart[i],
          endTime: draftEnd[i],
        ),
      );
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
