import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../credentials/data/repositories/credentials_repository.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/repositories/compliance_ops_repository.dart';

class StaffComplianceController extends GetxController {
  StaffComplianceController({
    required ComplianceOpsRepository repository,
    required CredentialsRepository credentialsRepository,
    required EngagementsRepository engagementsRepository,
    required SessionService session,
  }) : _repository = repository,
       _credentialsRepository = credentialsRepository,
       _engagementsRepository = engagementsRepository,
       _session = session;

  final ComplianceOpsRepository _repository;
  final CredentialsRepository _credentialsRepository;
  final EngagementsRepository _engagementsRepository;
  final SessionService _session;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final rights = <RightsRequestOut>[].obs;
  final accessHistory = <AccessHistoryEntry>[].obs;
  final accessHistoryError = RxnString();
  final isLoadingAccessHistory = false.obs;
  final contractorOptions = <EngagementOut>[].obs;
  final isLoadingContractors = false.obs;
  final selectedContractorId = RxnString();
  final credentialOptions = <CredentialOut>[].obs;
  final isLoadingCredentials = false.obs;
  final selectedCredentialId = RxnString();
  final incidents = <IncidentOut>[].obs;
  final selectedIncident = Rxn<IncidentOut>();
  final events = <NotificationEventOut>[].obs;

  final incidentTitleCtrl = TextEditingController();
  final incidentDescCtrl = TextEditingController();
  var _hasLoadedContractors = false;

  bool get canRights =>
      _session.hasPermission(AppPermissions.complianceRightsManage);
  bool get canAudit =>
      _session.hasPermission(AppPermissions.complianceAuditView);
  bool get canIncidents =>
      _session.hasPermission(AppPermissions.complianceIncidentsManage);
  bool get canReviewCreds =>
      _session.hasPermission(AppPermissions.credentialsReview);
  bool get canReadCredentials =>
      _session.hasPermission(AppPermissions.credentialsRead);

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

  Future<void> openAccessHistory() async {
    tabIndex.value = 1;
    if (!_hasLoadedContractors) await loadContractors();
  }

  Future<void> loadContractors() async {
    isLoadingContractors.value = true;
    accessHistoryError.value = null;
    try {
      final engagements = await _engagementsRepository.listTenantEngagements();
      final uniqueByContractorId = <String, EngagementOut>{};
      for (final engagement in engagements) {
        uniqueByContractorId.putIfAbsent(
          engagement.contractorId,
          () => engagement,
        );
      }
      contractorOptions.assignAll(uniqueByContractorId.values);
      _hasLoadedContractors = true;
    } on AppFailure catch (e) {
      accessHistoryError.value = e.message;
    } catch (_) {
      accessHistoryError.value = 'Could not load contractors.';
    } finally {
      isLoadingContractors.value = false;
    }
  }

  String contractorLabel(EngagementOut contractor) {
    final name = contractor.contractorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = contractor.contractorId;
    if (id.length <= 8) return 'Contractor ${id.substring(0, 4)}…';
    return 'Contractor ${id.substring(0, 4)}…${id.substring(id.length - 4)}';
  }

  void selectContractor(EngagementOut? contractor) {
    final contractorId = contractor?.contractorId;
    if (selectedContractorId.value == contractorId) return;
    selectedContractorId.value = contractorId;
    selectedCredentialId.value = null;
    accessHistory.clear();
    credentialOptions.clear();
    accessHistoryError.value = null;
  }

  void clearSelectedContractor() => selectContractor(null);

  Future<void> loadContractorCredentials() async {
    if (!canReadCredentials) {
      accessHistoryError.value = 'Missing credentials.read permission.';
      return;
    }
    final contractorId = selectedContractorId.value;
    if (contractorId == null || contractorId.isEmpty) {
      accessHistoryError.value = 'Select a contractor.';
      return;
    }
    isLoadingCredentials.value = true;
    accessHistoryError.value = null;
    selectedCredentialId.value = null;
    accessHistory.clear();
    credentialOptions.clear();
    try {
      credentialOptions.assignAll(
        await _credentialsRepository.listForTenantContractor(contractorId),
      );
      if (credentialOptions.isEmpty) {
        accessHistoryError.value = 'No credentials found for this contractor.';
      }
    } on AppFailure catch (e) {
      accessHistoryError.value = e.message;
    } finally {
      isLoadingCredentials.value = false;
    }
  }

  Future<void> selectCredential(String? credentialId) async {
    selectedCredentialId.value = credentialId;
    accessHistory.clear();
    accessHistoryError.value = null;
    if (credentialId == null || credentialId.isEmpty) return;
    await loadAccessHistoryForCredential(credentialId);
  }

  Future<void> loadAccessHistoryForCredential(String credentialId) async {
    isLoadingAccessHistory.value = true;
    accessHistoryError.value = null;
    try {
      accessHistory.assignAll(
        await _repository.listAccessHistory(credentialId: credentialId),
      );
    } on AppFailure catch (e) {
      accessHistoryError.value = e.message;
    } finally {
      isLoadingAccessHistory.value = false;
    }
  }

  Future<void> refreshAccessHistory() async {
    final id = selectedCredentialId.value;
    if (id != null && id.isNotEmpty) {
      await loadAccessHistoryForCredential(id);
    }
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
      final updated = await _repository.patchIncident(
        incident.id,
        status: 'closed',
      );
      selectedIncident.value = updated;
      incidents.assignAll(await _repository.listIncidents());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
