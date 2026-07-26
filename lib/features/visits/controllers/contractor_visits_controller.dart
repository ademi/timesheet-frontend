import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';
import '../services/visit_location_service.dart';

class ContractorVisitsController extends GetxController {
  ContractorVisitsController({
    required VisitsRepository repository,
    required SessionService session,
    VisitLocationService location = const VisitLocationService(),
  })  : _repository = repository,
        _session = session,
        _location = location;

  final VisitsRepository _repository;
  final SessionService _session;
  final VisitLocationService _location;

  final visits = <VisitOut>[].obs;
  final selected = Rxn<VisitOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final formNotesCtrl = TextEditingController();

  bool get isWeb => _location.isWeb;

  bool get canCheckIn =>
      _session.hasPermission(AppPermissions.visitsCheckIn);
  bool get canComplete =>
      _session.hasPermission(AppPermissions.visitsComplete);
  bool get canRead =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      canCheckIn ||
      canComplete;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    formNotesCtrl.dispose();
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
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).toUtc();
      final to = from.add(const Duration(days: 14));
      final list = await _repository.listVisits(from: from, to: to);
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

  Future<void> openDetail(VisitOut visit) async {
    selected.value = visit;
    Get.toNamed(AppRoutes.contractorVisitDetail, arguments: visit);
    await refreshSelected();
  }

  void hydrateFromArgs() {
    final arg = Get.arguments;
    if (arg is VisitOut) selected.value = arg;
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

  Future<void> toggleTask(VisitTaskOut task) async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.patchTask(
        visitId: visit.id,
        taskId: task.id,
        isDone: !task.isDone,
      );
      final tasks = visit.tasks
          .map((t) => t.id == updated.id ? updated : t)
          .toList(growable: false);
      selected.value = visit.copyWith(tasks: tasks);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> submitForm(VisitFormRequirement req) async {
    final visit = selected.value;
    if (visit == null) return;
    final notes = formNotesCtrl.text.trim();
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.submitForm(
        visitId: visit.id,
        body: VisitFormSubmitRequest(
          formTemplateId: req.formTemplateId,
          payloadJson: {
            'notes': notes.isEmpty ? 'Submitted' : notes,
          },
        ),
      );
      formNotesCtrl.clear();
      await refreshSelected();
      Get.snackbar(
        'Form submitted',
        req.name ?? req.formTemplateId,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> checkIn() async {
    final visit = selected.value;
    if (visit == null) return;
    if (isWeb) {
      errorMessage.value = VisitLocationService.webBlockedMessage;
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final gps = await _location.requireGps();
      final result = await _repository.checkIn(
        id: visit.id,
        body: gps,
        idempotencyKey: 'checkin-${visit.id}',
      );
      selected.value = visit.copyWith(status: result.status);
      await refreshSelected();
      Get.snackbar(
        'Checked in',
        'Visit is now ${result.status}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on VisitLocationException catch (e) {
      errorMessage.value = e.message;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> complete() async {
    final visit = selected.value;
    if (visit == null) return;
    if (isWeb) {
      errorMessage.value = VisitLocationService.webBlockedMessage;
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final gps = await _location.requireGps();
      final result = await _repository.complete(
        id: visit.id,
        body: gps,
        idempotencyKey: 'complete-${visit.id}',
      );
      selected.value = visit.copyWith(
        status: result.status,
        completedAt: result.completedAt,
      );
      await refreshSelected();
      Get.snackbar(
        'Completed',
        'Visit marked completed.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on VisitLocationException catch (e) {
      errorMessage.value = e.message;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }
}
