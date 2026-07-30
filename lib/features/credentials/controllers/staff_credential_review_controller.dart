import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../data/models/credential_models.dart';
import '../data/repositories/credentials_repository.dart';

/// Staff metadata list + review decisions (design §5.6 / §6.4).
///
/// Args via Get.parameters / Get.arguments:
/// `contractorId`, `engagementId`.
class StaffCredentialReviewController extends GetxController {
  StaffCredentialReviewController({
    required CredentialsRepository repository,
    required SessionService session,
  }) : _repository = repository,
       _session = session;

  final CredentialsRepository _repository;
  final SessionService _session;

  final reasonCtrl = TextEditingController();
  String? _contractorId;
  String? _engagementId;

  final items = <CredentialOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final eligibilityReasons = <String>[].obs;
  final mfaRequired = false.obs;

  bool get canReview =>
      _session.hasPermission(AppPermissions.credentialsReview);

  bool get canRead => _session.hasPermission(AppPermissions.credentialsRead);
  bool get hasReviewContext => _contractorId != null && _engagementId != null;

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    final args = Get.arguments;
    String? contractorId = params['contractorId'];
    String? engagementId = params['engagementId'];
    if (args is Map) {
      contractorId ??= args['contractorId']?.toString();
      engagementId ??= args['engagementId']?.toString();
    }
    _contractorId = contractorId;
    _engagementId = engagementId;
    if (_contractorId != null) {
      load();
    }
  }

  @override
  void onClose() {
    reasonCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing credentials.read permission.';
      return;
    }
    final contractorId = _contractorId;
    if (contractorId == null) {
      errorMessage.value = 'Open credential review from Workforce.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    eligibilityReasons.clear();
    try {
      final list = await _repository.listForTenantContractor(contractorId);
      items.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (e.isEligibilityIncomplete) {
        eligibilityReasons.assignAll(e.eligibilityReasons);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitReview({
    required CredentialOut credential,
    required String decision,
  }) async {
    if (!canReview) {
      errorMessage.value = 'Missing credentials.review permission.';
      return;
    }
    final engagementId = _engagementId;
    if (engagementId == null) {
      errorMessage.value = 'Open credential review from Workforce.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    mfaRequired.value = false;
    eligibilityReasons.clear();
    try {
      await _repository.createReview(
        engagementId: engagementId,
        body: CredentialReviewCreateRequest(
          credentialId: credential.id,
          decision: decision,
          reasonCode:
              reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
        ),
      );
      Get.snackbar(
        'Review recorded',
        'Decision: $decision',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
      await load();
    } on AppFailure catch (e) {
      if (e.code == 'mfa_required') {
        mfaRequired.value = true;
        errorMessage.value =
            'MFA required for credential review. Complete MFA, then retry.';
      } else {
        errorMessage.value = e.message;
        if (e.isEligibilityIncomplete) {
          eligibilityReasons.assignAll(e.eligibilityReasons);
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }
}
