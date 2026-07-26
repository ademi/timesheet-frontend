import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';

class StaffVisitsController extends GetxController {
  StaffVisitsController({
    required VisitsRepository repository,
    required SessionService session,
  })  : _repository = repository,
        _session = session;

  final VisitsRepository _repository;
  final SessionService _session;

  final visits = <VisitOut>[].obs;
  final selected = Rxn<VisitOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  /// Board range: default current local day → +7 days.
  final rangeStart = DateTime.now().obs;
  final jobIdFilter = ''.obs;
  final statusFilter = ''.obs;

  final jobIdCtrl = TextEditingController();

  bool get canManage => _session.hasPermission(AppPermissions.visitsManage);
  bool get canRead =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  DateTime get _fromUtc {
    final d = rangeStart.value;
    return DateTime(d.year, d.month, d.day).toUtc();
  }

  DateTime get _toUtc => _fromUtc.add(const Duration(days: 7));

  @override
  void onInit() {
    super.onInit();
    applyRouteArgs();
    load();
  }

  void applyRouteArgs() {
    final args = Get.arguments;
    if (args is Map && args['job_id'] != null) {
      final id = args['job_id'].toString();
      if (id != jobIdFilter.value) {
        jobIdFilter.value = id;
        jobIdCtrl.text = id;
        load();
      } else {
        jobIdCtrl.text = id;
      }
    }
  }

  @override
  void onClose() {
    jobIdCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing visits.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.listVisits(
        from: _fromUtc,
        to: _toUtc,
        jobId: jobIdFilter.value.trim().isEmpty ? null : jobIdFilter.value.trim(),
        status: statusFilter.value.trim().isEmpty ? null : statusFilter.value.trim(),
      );
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      visits.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void applyFilters() {
    jobIdFilter.value = jobIdCtrl.text.trim();
    load();
  }

  void shiftRange(int days) {
    rangeStart.value = rangeStart.value.add(Duration(days: days));
    load();
  }

  void setStatusFilter(String? status) {
    statusFilter.value = status ?? '';
    load();
  }

  Future<void> openDetail(VisitOut visit) async {
    selected.value = visit;
    Get.toNamed(AppRoutes.staffVisitDetail, arguments: visit);
    await refreshSelected();
  }

  Future<void> refreshSelected() async {
    final id = selected.value?.id ??
        (Get.arguments is VisitOut ? (Get.arguments as VisitOut).id : null);
    if (id == null) return;
    try {
      selected.value = await _repository.getVisit(id);
      final idx = visits.indexWhere((v) => v.id == id);
      if (idx >= 0 && selected.value != null) {
        visits[idx] = selected.value!;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
  }

  void hydrateFromArgs() {
    final arg = Get.arguments;
    if (arg is VisitOut) selected.value = arg;
  }

  Future<void> cancelSelected() async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.cancel(visit.id);
      await refreshSelected();
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> rescheduleSelected({
    required DateTime start,
    required DateTime end,
  }) async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      selected.value = await _repository.reschedule(
        id: visit.id,
        scheduledStart: start,
        scheduledEnd: end,
      );
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
