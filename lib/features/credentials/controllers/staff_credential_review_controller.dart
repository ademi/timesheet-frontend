import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../documents/data/evidence_document_opener.dart';
import '../../documents/data/document_pipeline.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../data/evidence_documents.dart';
import '../data/models/credential_models.dart';
import '../data/repositories/credentials_repository.dart';

/// Staff metadata list + review decisions (design §5.6 / §6.4).
///
/// Args via Get.parameters / Get.arguments:
/// `contractorId`, `engagementId`.
class StaffCredentialReviewController extends GetxController {
  StaffCredentialReviewController({
    required CredentialsRepository repository,
    required EngagementsRepository engagementsRepository,
    required SessionService session,
    required DocumentPipeline documentPipeline,
    EvidenceDocumentOpener? evidenceDocumentOpener,
    String? contractorId,
    String? engagementId,
    void Function(String title, String message)? showSnack,
  }) : _repository = repository,
       _engagementsRepository = engagementsRepository,
       _session = session,
       _pipeline = documentPipeline,
       _evidenceDocumentOpener =
           evidenceDocumentOpener ??
           EvidenceDocumentOpener(documentPipeline: documentPipeline),
       _contractorId = contractorId,
       _engagementId = engagementId,
       _showSnack = showSnack ?? _defaultSnack;

  final CredentialsRepository _repository;
  final EngagementsRepository _engagementsRepository;
  final SessionService _session;
  final DocumentPipeline _pipeline;
  final EvidenceDocumentOpener _evidenceDocumentOpener;
  final void Function(String title, String message) _showSnack;

  static void _defaultSnack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.primary,
      colorText: AppColors.onPrimary,
    );
  }

  final reasonCtrl = TextEditingController();
  String? _contractorId;
  String? _engagementId;

  final items = <CredentialOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isRequestingShare = false.obs;
  final needsShareRequest = false.obs;
  final errorMessage = RxnString();
  final eligibilityReasons = <String>[].obs;
  final mfaRequired = false.obs;
  final evidenceByCredentialId = <String, List<DocumentOut>>{}.obs;

  bool get canReview =>
      _session.hasPermission(AppPermissions.credentialsReview);

  bool get canRead => _session.hasPermission(AppPermissions.credentialsRead);
  bool get hasReviewContext => _contractorId != null && _engagementId != null;

  List<DocumentOut> evidenceFor(CredentialOut credential) {
    return evidenceByCredentialId[credential.id] ?? const [];
  }

  @override
  void onInit() {
    super.onInit();
    final params = Get.parameters;
    final args = Get.arguments;
    _contractorId ??= params['contractorId'];
    _engagementId ??= params['engagementId'];
    if (args is Map) {
      _contractorId ??= args['contractorId']?.toString();
      _engagementId ??= args['engagementId']?.toString();
    }
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
    final engagementId = _engagementId;
    if (contractorId == null || engagementId == null) {
      errorMessage.value = 'Open credential review from Workforce.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    needsShareRequest.value = false;
    eligibilityReasons.clear();
    try {
      final list = await _repository.listForTenantContractor(
        contractorId,
        engagementId: engagementId,
      );
      items.assignAll(list);
      final documents = await _pipeline.listEvidenceForContractor(contractorId);
      evidenceByCredentialId.value = {
        for (final credential in list)
          credential.id: documentsForCredential(
            documents: documents,
            credentialId: credential.id,
            credentialType: credential.credentialType,
          ),
      };
    } on AppFailure catch (e) {
      items.clear();
      evidenceByCredentialId.clear();
      if (e.isSharingGrantRequired) {
        needsShareRequest.value = true;
        errorMessage.value = null;
      } else {
        errorMessage.value = e.message;
        if (e.isEligibilityIncomplete) {
          eligibilityReasons.assignAll(e.eligibilityReasons);
        }
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> requestAccess() async {
    final engagementId = _engagementId;
    if (engagementId == null) {
      errorMessage.value = 'Open credential review from Workforce.';
      return false;
    }
    isRequestingShare.value = true;
    errorMessage.value = null;
    try {
      await _engagementsRepository.createSharingAccessRequest(
        engagementId: engagementId,
      );
      _showSnack(
        'Request sent',
        'Request sent. Waiting for contractor approval.',
      );
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      isRequestingShare.value = false;
    }
  }

  Future<void> openEvidenceDocument(
    DocumentOut document, {
    bool download = false,
  }) async {
    errorMessage.value = null;
    isSaving.value = true;
    try {
      await _evidenceDocumentOpener.open(document, download: download);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'Could not download this file. Check your connection and retry.';
    } finally {
      isSaving.value = false;
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
      _showSnack('Review recorded', 'Decision: $decision');
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
