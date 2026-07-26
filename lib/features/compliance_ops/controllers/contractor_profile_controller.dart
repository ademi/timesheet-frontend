import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/repositories/compliance_ops_repository.dart';

class ContractorProfileController extends GetxController {
  ContractorProfileController({
    required ComplianceOpsRepository repository,
    required SessionService session,
  })  : _repository = repository,
        _session = session;

  final ComplianceOpsRepository _repository;
  final SessionService _session;

  final isSaving = false.obs;
  final errorMessage = RxnString();
  final lastRights = Rxn<RightsRequestOut>();
  final lastExport = Rxn<PrivacyExportResult>();
  final events = <NotificationEventOut>[].obs;

  final rightsNotesCtrl = TextEditingController();
  final rightsType = 'access'.obs;
  final withdrawTypeCtrl = TextEditingController(text: 'police_check');

  bool get canConsent =>
      _session.hasPermission(AppPermissions.complianceConsentManage);

  @override
  void onInit() {
    super.onInit();
    _loadEvents();
  }

  @override
  void onClose() {
    rightsNotesCtrl.dispose();
    withdrawTypeCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadEvents() async {
    try {
      events.assignAll(await _repository.listNotificationEvents());
    } catch (_) {}
  }

  Future<void> submitRightsRequest() async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final created = await _repository.createRightsRequest(
        RightsRequestCreate(
          requestType: rightsType.value,
          notes: rightsNotesCtrl.text,
        ),
      );
      lastRights.value = created;
      rightsNotesCtrl.clear();
      Get.snackbar(
        'Request submitted',
        '${created.requestType} · ${created.status}',
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

  Future<void> runPrivacyExport() async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.privacyExport();
      lastExport.value = result;
      Get.snackbar(
        'Privacy export',
        result.message ?? result.downloadUrl ?? 'Export requested',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> confirmWithdrawConsent() async {
    if (!canConsent) {
      errorMessage.value = 'Missing compliance.consent.manage.';
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Withdraw consent?'),
        content: const Text(
          'Withdrawing sensitive-data consent may block future platform-mediated '
          'access to that credential class. Your provider may still retain lawful '
          'copies outside this app. This does not delete historical records by itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.withdrawConsent(
        credentialType: withdrawTypeCtrl.text.trim(),
      );
      Get.snackbar(
        'Consent withdrawn',
        'Recorded for ${withdrawTypeCtrl.text.trim()}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
