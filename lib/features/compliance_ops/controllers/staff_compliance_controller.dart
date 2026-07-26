import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/repositories/compliance_ops_repository.dart';

class StaffComplianceController extends GetxController {
  StaffComplianceController({
    required ComplianceOpsRepository repository,
    required SessionService session,
  })  : _repository = repository,
        _session = session;

  final ComplianceOpsRepository _repository;
  final SessionService _session;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final rights = <RightsRequestOut>[].obs;
  final accessHistory = <AccessHistoryEntry>[].obs;
  final incidents = <IncidentOut>[].obs;
  final selectedIncident = Rxn<IncidentOut>();
  final events = <NotificationEventOut>[].obs;

  final incidentTitleCtrl = TextEditingController();
  final incidentDescCtrl = TextEditingController();

  bool get canRights =>
      _session.hasPermission(AppPermissions.complianceRightsManage);
  bool get canAudit =>
      _session.hasPermission(AppPermissions.complianceAuditView);
  bool get canIncidents =>
      _session.hasPermission(AppPermissions.complianceIncidentsManage);
  bool get canReviewCreds =>
      _session.hasPermission(AppPermissions.credentialsReview);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    incidentTitleCtrl.dispose();
    incidentDescCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    if (canRights) {
      try {
        rights.assignAll(await _repository.listRightsRequests());
      } on AppFailure catch (e) {
        await BillingGate.showIfNeeded(e);
        errorMessage.value = e.message;
      }
    }
    if (canAudit) {
      try {
        accessHistory.assignAll(await _repository.listAccessHistory());
      } on AppFailure catch (e) {
        errorMessage.value ??= e.message;
      }
    }
    if (canIncidents) {
      try {
        incidents.assignAll(await _repository.listIncidents());
      } on AppFailure catch (e) {
        errorMessage.value ??= e.message;
      }
    }
    try {
      events.assignAll(await _repository.listNotificationEvents());
    } on AppFailure catch (_) {
      // optional for staff without notifications.receive
    }
    isLoading.value = false;
  }

  Future<void> openIncident(IncidentOut incident) async {
    isSaving.value = true;
    try {
      selectedIncident.value = await _repository.getIncident(incident.id);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      selectedIncident.value = incident;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> createIncident() async {
    if (!canIncidents) return;
    final title = incidentTitleCtrl.text.trim();
    if (title.isEmpty) {
      errorMessage.value = 'Incident title is required.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.createIncident(
        IncidentCreate(
          title: title,
          description: incidentDescCtrl.text,
          discoveredAt: DateTime.now().toUtc(),
        ),
      );
      incidentTitleCtrl.clear();
      incidentDescCtrl.clear();
      incidents.assignAll(await _repository.listIncidents());
      Get.snackbar(
        'Incident created',
        'Recorded for compliance follow-up.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> closeIncident(IncidentOut incident) async {
    if (!canIncidents) return;
    isSaving.value = true;
    try {
      final updated =
          await _repository.patchIncident(incident.id, status: 'closed');
      selectedIncident.value = updated;
      incidents.assignAll(await _repository.listIncidents());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
