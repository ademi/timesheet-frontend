import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/name_sort.dart';
import '../../documents/data/evidence_document_opener.dart';
import '../../documents/data/document_pipeline.dart';
import '../../engagements/controllers/workforce_controller.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../data/evidence_documents.dart';
import '../data/models/credential_models.dart';
import '../data/repositories/credentials_repository.dart';
import '../widgets/credential_review_actions.dart';
import '../widgets/credential_status_chip.dart';

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
    List<String>? initialRequiredCategories,
    bool canEditRequiredDocs = false,
    bool isEnded = false,
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
       _initialRequiredCategories = initialRequiredCategories,
       _initialCanEditRequiredDocs = canEditRequiredDocs,
       _initialIsEnded = isEnded,
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
  final selectedReasonCode = RxnString();
  String? _contractorId;
  String? _engagementId;
  final List<String>? _initialRequiredCategories;
  final bool _initialCanEditRequiredDocs;
  final bool _initialIsEnded;

  /// Optional reason codes for credential review decisions (WF-4).
  static const reasonCodeOptions = <(String, String)>[
    ('incomplete_evidence', 'Incomplete evidence'),
    ('expired_document', 'Expired document'),
    ('unreadable_scan', 'Unreadable scan'),
    ('wrong_document_type', 'Wrong document type'),
    ('name_mismatch', 'Name mismatch'),
    ('other', 'Other'),
  ];

  String? get effectiveReasonCode {
    final selected = selectedReasonCode.value?.trim();
    if (selected != null && selected.isNotEmpty) return selected;
    final typed = reasonCtrl.text.trim();
    return typed.isEmpty ? null : typed;
  }

  final items = <CredentialOut>[].obs;
  final isLoading = false.obs;
  final isRequestingShare = false.obs;
  final needsShareRequest = false.obs;
  final errorMessage = RxnString();
  final eligibilityReasons = <String>[].obs;
  final mfaRequired = false.obs;
  final evidenceByCredentialId = <String, List<DocumentOut>>{}.obs;
  final reviewDecisionsByCredentialId = <String, String>{}.obs;
  final reviewingCredentialId = RxnString();
  final reviewingDecision = RxnString();
  final openingEvidenceCredentialId = RxnString();
  final reasonCredentialId = RxnString();
  final pendingReasonDecision = RxnString();
  final requiredCategories = <String>{}.obs;
  final catalogCategories = <CredentialCategory>[].obs;
  final isLoadingCatalog = false.obs;
  final isSavingRequiredDocs = false.obs;

  bool _canEditRequiredDocs = false;
  bool _isEnded = false;

  bool get canReview =>
      _session.hasPermission(AppPermissions.credentialsReview);

  bool get canRead => _session.hasPermission(AppPermissions.credentialsRead);
  bool get canManage =>
      _session.hasPermission(AppPermissions.contractorsManage);
  bool get canEditRequiredDocs => _canEditRequiredDocs;
  bool get isEnded => _isEnded;
  bool get hasReviewContext => _contractorId != null && _engagementId != null;

  List<CredentialCategory> get categoryChoices {
    final choices =
        catalogCategories.isNotEmpty
            ? catalogCategories.toList()
            : credentialTypesAllowlist
                .map(
                  (code) => CredentialCategory(
                    code: code,
                    label: credentialTypeLabel(code),
                  ),
                )
                .toList();
    return sortedByName(choices, (c) => c.label);
  }

  List<DocumentOut> evidenceFor(CredentialOut credential) {
    return evidenceByCredentialId[credential.id] ?? const [];
  }

  String? reviewDecisionFor(String credentialId) {
    return reviewDecisionsByCredentialId[credentialId];
  }

  CredentialReviewButtonState reviewActionsFor(String credentialId) {
    return credentialReviewButtonState(reviewDecisionFor(credentialId));
  }

  bool isReviewActionLoading(String credentialId, String decision) {
    return reviewingCredentialId.value == credentialId &&
        reviewingDecision.value == decision;
  }

  bool isEvidenceBusy(String credentialId) {
    return openingEvidenceCredentialId.value == credentialId;
  }

  static const _reviewStatuses = {
    'accepted',
    'rejected',
    're_review_required',
    'pending',
  };

  void _seedDecisionsFromStatus(List<CredentialOut> list) {
    final updated = Map<String, String>.from(reviewDecisionsByCredentialId);
    for (final credential in list) {
      if (_reviewStatuses.contains(credential.status)) {
        updated[credential.id] = credential.status;
      }
    }
    reviewDecisionsByCredentialId.value = updated;
  }

  bool isReasonPickerOpenFor(String credentialId, String decision) {
    return reasonCredentialId.value == credentialId &&
        pendingReasonDecision.value == decision;
  }

  bool decisionRequiresReason(String decision) {
    return decision == 'rejected' || decision == 're_review_required';
  }

  void prepareReview({
    required CredentialOut credential,
    required String decision,
  }) {
    errorMessage.value = null;
    if (!decisionRequiresReason(decision)) {
      clearPendingReason();
      submitReview(credential: credential, decision: decision);
      return;
    }
    reasonCredentialId.value = credential.id;
    pendingReasonDecision.value = decision;
    selectedReasonCode.value = null;
  }

  void clearPendingReason() {
    reasonCredentialId.value = null;
    pendingReasonDecision.value = null;
    selectedReasonCode.value = null;
  }

  Future<void> confirmPendingReview(CredentialOut credential) async {
    final decision = pendingReasonDecision.value;
    if (reasonCredentialId.value != credential.id || decision == null) return;
    await submitReview(credential: credential, decision: decision);
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
      final cats = args['requiredCategories'];
      if (cats is List) {
        requiredCategories
          ..clear()
          ..addAll(cats.map((e) => e.toString()));
      }
      if (args.containsKey('canEditRequiredDocs')) {
        _canEditRequiredDocs = args['canEditRequiredDocs'] == true;
      }
      if (args.containsKey('isEnded')) {
        _isEnded = args['isEnded'] == true;
      }
    } else {
      _canEditRequiredDocs = _initialCanEditRequiredDocs;
      _isEnded = _initialIsEnded;
      if (_initialRequiredCategories != null) {
        requiredCategories.assignAll(_initialRequiredCategories);
      }
    }
    if (_canEditRequiredDocs) {
      loadCredentialCategories();
    }
    if (_contractorId != null) {
      load();
    }
  }

  void toggleRequiredCategory(String category) {
    if (requiredCategories.contains(category)) {
      requiredCategories.remove(category);
    } else {
      requiredCategories.add(category);
    }
  }

  Future<void> loadCredentialCategories() async {
    isLoadingCatalog.value = true;
    try {
      final list = await _repository.listCredentialCategories();
      catalogCategories.assignAll(list);
    } on AppFailure {
      // Keep allowlist fallback via [categoryChoices].
    } catch (_) {
      // Keep allowlist fallback via [categoryChoices].
    } finally {
      isLoadingCatalog.value = false;
    }
  }

  Future<void> saveRequiredDocCategories() async {
    if (!canManage || _engagementId == null) return;
    if (requiredCategories.isEmpty) {
      errorMessage.value =
          'At least one required document category is required.';
      return;
    }
    isSavingRequiredDocs.value = true;
    errorMessage.value = null;
    try {
      final updated = await _engagementsRepository.replaceRequiredDocCategories(
        engagementId: _engagementId!,
        categories: requiredCategories.toList(),
      );
      requiredCategories
        ..clear()
        ..addAll(updated.requiredDocCategories.map((c) => c.category));
      if (Get.isRegistered<WorkforceController>()) {
        final workforce = Get.find<WorkforceController>();
        workforce.selected = updated;
        final idx = workforce.items.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) {
          workforce.items[idx] = updated;
        }
        workforce.detailSelectedCategories
          ..clear()
          ..addAll(updated.requiredDocCategories.map((c) => c.category));
      }
      _showSnack('Saved', 'Required certificates updated.');
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSavingRequiredDocs.value = false;
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
      _seedDecisionsFromStatus(list);
      try {
        final documents = await _pipeline.listEvidenceForContractor(
          contractorId,
        );
        evidenceByCredentialId.value = {
          for (final credential in list)
            credential.id: documentsForCredential(
              documents: documents,
              credentialId: credential.id,
              credentialType: credential.credentialType,
            ),
        };
      } catch (e) {
        evidenceByCredentialId.clear();
        errorMessage.value =
            e is AppFailure
                ? e.message
                : 'Could not load evidence files. Retry to view or download.';
      }
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
    required String credentialId,
    bool download = false,
  }) async {
    errorMessage.value = null;
    openingEvidenceCredentialId.value = credentialId;
    try {
      await _evidenceDocumentOpener.open(document, download: download);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'Could not download this file. Check your connection and retry.';
    } finally {
      openingEvidenceCredentialId.value = null;
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
    reviewingCredentialId.value = credential.id;
    reviewingDecision.value = decision;
    errorMessage.value = null;
    mfaRequired.value = false;
    eligibilityReasons.clear();
    try {
      final review = await _repository.createReview(
        engagementId: engagementId,
        body: CredentialReviewCreateRequest(
          credentialId: credential.id,
          decision: decision,
          reasonCode: effectiveReasonCode,
        ),
      );
      reviewDecisionsByCredentialId[credential.id] = review.decision;
      _showSnack(
        'Review recorded',
        '${credentialTypeLabel(credential.credentialType)}: '
        '${credentialStatusLabel(review.decision)}',
      );
      clearPendingReason();
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
      reviewingCredentialId.value = null;
      reviewingDecision.value = null;
    }
  }
}
