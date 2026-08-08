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
  final isRefreshing = false.obs;
  final errorMessage = RxnString();

  final manualTemplateIdCtrl = TextEditingController();

  /// Template ids submitted this session (until visit refresh returns summaries).
  final submittedTemplateIds = <String>{}.obs;

  bool get isWeb => _location.isWeb;

  bool get canCheckIn =>
      _session.hasPermission(AppPermissions.visitsCheckIn);
  bool get canComplete =>
      _session.hasPermission(AppPermissions.visitsComplete);
  bool get canRead =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      canCheckIn ||
      canComplete;

  List<VisitFormRequirement> get effectiveFormRequirements =>
      selected.value?.formRequirements ?? const [];

  bool isFormSubmitted(String formTemplateId) {
    if (submittedTemplateIds.contains(formTemplateId)) return true;
    final visit = selected.value;
    if (visit == null) return false;
    return visit.formSubmissions
        .any((s) => s.formTemplateId == formTemplateId);
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    manualTemplateIdCtrl.dispose();
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
    submittedTemplateIds.clear();
    Get.toNamed(AppRoutes.contractorVisitDetail, arguments: visit);
    await refreshSelected();
  }

  void hydrateFromArgs() {
    final arg = Get.arguments;
    if (arg is VisitOut) selected.value = arg;
  }

  Future<void> refreshSelected() async {
    final id = selected.value?.id ?? _visitIdFromArgs(Get.arguments);
    if (id == null) return;
    isRefreshing.value = true;
    try {
      final visit = await _repository.getVisit(id);
      selected.value = visit;
      final idx = visits.indexWhere((v) => v.id == id);
      if (idx >= 0) {
        visits[idx] = visit;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> submitForm(
    VisitFormRequirement req, {
    required Map<String, dynamic> payloadJson,
  }) async {
    final visit = selected.value;
    if (visit == null) return;
    if (payloadJson.isEmpty) {
      errorMessage.value = 'Form payload is empty.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.submitForm(
        visitId: visit.id,
        body: VisitFormSubmitRequest(
          formTemplateId: req.formTemplateId,
          payloadJson: payloadJson,
        ),
      );
      submittedTemplateIds.add(req.formTemplateId);
      await refreshSelected();
      Get.snackbar(
        'Form submitted',
        req.name ?? req.formTemplateId,
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
      if (e.code == 'forms_incomplete' ||
          e.code == 'required_forms_incomplete') {
        errorMessage.value = effectiveFormRequirements.isEmpty
            ? 'Required forms are incomplete. Submit the progress form '
                'listed above (or ask staff to attach form requirements '
                'to the visit), then Complete again.'
            : e.message;
      } else {
        errorMessage.value = e.message;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }
}

String? _visitIdFromArgs(Object? arg) {
  if (arg is VisitOut) return arg.id;
  if (arg is String && arg.isNotEmpty) return arg;
  return null;
}
