import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_profile_models.dart';
import '../data/repositories/clients_repository.dart';
import '../services/client_legal_upload_helper.dart';
import '../utils/onboarding_keys.dart';

/// Care-plan Funding + Consent collaborator (facts/legal; not plan body_json).
class SupportPlanFundingConsentStore {
  SupportPlanFundingConsentStore({
    required ClientsRepository repository,
    DocumentPipeline? documentPipeline,
    Future<({String name, List<int> bytes})?> Function()? pickPdfBytes,
    bool Function()? canUploadDocs,
    VoidCallback? onReload,
  }) : _repository = repository,
       _pipeline = documentPipeline,
       _pickPdfBytes = pickPdfBytes,
       _canUploadDocs = canUploadDocs ?? (() => true),
       onReload = onReload;

  final ClientsRepository _repository;
  final DocumentPipeline? _pipeline;
  final Future<({String name, List<int> bytes})?> Function()? _pickPdfBytes;
  final bool Function() _canUploadDocs;

  /// Invoked after a failed persist or Discard so the parent can re-fetch.
  VoidCallback? onReload;

  final isLoading = false.obs;
  final isBusy = false.obs;
  final errorMessage = RxnString();

  /// False until [applyProfileBundle] / [reload] succeeds (D10).
  bool hasHydrated = false;

  final _presentKeys = <String>{};

  // ── Funding ───────────────────────────────────────────────────────────
  final planManagementType = RxnString();
  final planManagerNameCtrl = TextEditingController();
  final planManagerPhoneCtrl = TextEditingController();
  final planManagerEmailCtrl = TextEditingController();
  final planStartDate = Rxn<DateTime>();
  final planEndDate = Rxn<DateTime>();
  final budgetCoreCtrl = TextEditingController();
  final budgetCbCtrl = TextEditingController();
  final budgetCapitalCtrl = TextEditingController();
  final fundingNotToExceedCtrl = TextEditingController();
  final scNameCtrl = TextEditingController();
  final scPhoneCtrl = TextEditingController();
  final scEmailCtrl = TextEditingController();
  final preferredClaimingMethod = RxnString();
  final preferredClaimingOtherCtrl = TextEditingController();
  final ndisPdfOnFile = false.obs;

  // ── Consent ───────────────────────────────────────────────────────────
  final infoShareConsent = false.obs;
  final specificSupportsConsent = false.obs;
  final consentAgreementComplete = false.obs;
  final serviceAgreementComplete = false.obs;
  final acknowledgementComplete = false.obs;
  final consentSignerNameCtrl = TextEditingController();

  ClientLegalUploadHelper get _legalHelper => ClientLegalUploadHelper(
        repository: _repository,
        pipeline: _pipeline,
        pickPdfBytes: _pickPdfBytes ??
            () async => throw const AppFailure(
                  code: 'unknown',
                  message: 'PDF picker is not configured.',
                  presentation: AppFailurePresentation.inline,
                ),
        canUploadDocs: _canUploadDocs,
      );

  void applyProfileBundle(ClientProfileBundle bundle) {
    _presentKeys
      ..clear()
      ..addAll(bundle.facts.map((f) => f.requirementKey));

    planManagementType.value = _stringFact(bundle, OnboardingKeys.planManagementType);
    planManagerNameCtrl.text =
        _stringFact(bundle, OnboardingKeys.planManagerName) ?? '';
    planManagerPhoneCtrl.text =
        _stringFact(bundle, OnboardingKeys.planManagerPhone) ?? '';
    planManagerEmailCtrl.text =
        _stringFact(bundle, OnboardingKeys.planManagerEmail) ?? '';
    planStartDate.value = _dateFact(bundle, OnboardingKeys.planStartDate);
    planEndDate.value = _dateFact(bundle, OnboardingKeys.planEndDate);
    budgetCoreCtrl.text = _numberText(bundle, OnboardingKeys.budgetCore);
    budgetCbCtrl.text = _numberText(bundle, OnboardingKeys.budgetCb);
    budgetCapitalCtrl.text = _numberText(bundle, OnboardingKeys.budgetCapital);
    fundingNotToExceedCtrl.text =
        _numberText(bundle, OnboardingKeys.fundingNotToExceed);
    scNameCtrl.text =
        _stringFact(bundle, OnboardingKeys.supportCoordinatorName) ?? '';
    scPhoneCtrl.text =
        _stringFact(bundle, OnboardingKeys.supportCoordinatorPhone) ?? '';
    scEmailCtrl.text =
        _stringFact(bundle, OnboardingKeys.supportCoordinatorEmail) ?? '';
    preferredClaimingMethod.value =
        _stringFact(bundle, OnboardingKeys.preferredClaimingMethod);
    preferredClaimingOtherCtrl.text =
        _stringFact(bundle, OnboardingKeys.preferredClaimingOtherDetail) ?? '';

    final ndis = _fact(bundle, OnboardingKeys.ndis);
    ndisPdfOnFile.value =
        ndis?.documentId != null && ndis!.documentId!.isNotEmpty;

    infoShareConsent.value =
        _boolFact(bundle, OnboardingKeys.infoShareConsent) ?? false;
    specificSupportsConsent.value =
        _boolFact(bundle, OnboardingKeys.specificSupportsConsent) ?? false;

    final legalKeys = bundle.legalAcceptances.map((a) => a.requirementKey).toSet();
    consentAgreementComplete.value =
        legalKeys.contains(OnboardingKeys.consentAgreement);
    serviceAgreementComplete.value =
        legalKeys.contains(OnboardingKeys.serviceAgreement) ||
            _fact(bundle, OnboardingKeys.serviceAgreement)?.documentId != null;
    acknowledgementComplete.value =
        legalKeys.contains(OnboardingKeys.acknowledgement) ||
            _fact(bundle, OnboardingKeys.acknowledgement)?.documentId != null;

    hasHydrated = true;
  }

  Future<void> reload(String clientId) async {
    if (clientId.isEmpty) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final bundle = await _repository.getClientProfile(clientId);
      applyProfileBundle(bundle);
      onReload?.call();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Soft draft may omit plan type; Activate requires it (D6=B).
  String? validateFunding({required bool requirePlanType}) {
    final planType = planManagementType.value;
    if (requirePlanType && (planType == null || planType.isEmpty)) {
      return 'Plan management type is required.';
    }
    if (planType == 'plan_managed') {
      if (planManagerNameCtrl.text.trim().isEmpty) {
        return 'Plan manager name is required for plan-managed.';
      }
      if (planManagerPhoneCtrl.text.trim().isEmpty &&
          planManagerEmailCtrl.text.trim().isEmpty) {
        return 'Plan manager phone or email is required for plan-managed.';
      }
    }
    if (preferredClaimingMethod.value == 'other' &&
        preferredClaimingOtherCtrl.text.trim().isEmpty) {
      return 'Describe the preferred claiming method.';
    }
    return null;
  }

  /// Upserts all owned funding/consent keys (D5=A) in parallel (D9=A).
  /// Returns failed key labels; empty means success.
  Future<List<String>> persistFacts({required String clientId}) async {
    if (!hasHydrated || clientId.isEmpty) return const [];

    final jobs = <({String key, String label, Future<void> future})>[];

    void putValue(String key, String label, Object? value) {
      if (value == null) return;
      if (value is String && value.isEmpty) {
        if (!_presentKeys.contains(key)) return; // D10: never-loaded empty
        jobs.add((
          key: key,
          label: label,
          future: _repository.upsertProfileFact(
            clientId,
            key,
            const ProfileFactUpsert(clearValue: true),
          ),
        ));
        return;
      }
      jobs.add((
        key: key,
        label: label,
        future: _repository.upsertProfileFact(
          clientId,
          key,
          ProfileFactUpsert(valueJson: value),
        ),
      ));
    }

    final planType = planManagementType.value?.trim();
    if (planType != null && planType.isNotEmpty) {
      putValue(OnboardingKeys.planManagementType, 'Plan management', planType);
    }

    if (planType == 'plan_managed') {
      putValue(
        OnboardingKeys.planManagerName,
        'Plan manager name',
        planManagerNameCtrl.text.trim(),
      );
      putValue(
        OnboardingKeys.planManagerPhone,
        'Plan manager phone',
        planManagerPhoneCtrl.text.trim(),
      );
      putValue(
        OnboardingKeys.planManagerEmail,
        'Plan manager email',
        planManagerEmailCtrl.text.trim(),
      );
    }

    putValue(
      OnboardingKeys.planStartDate,
      'Plan start',
      planStartDate.value == null ? '' : _formatDate(planStartDate.value!),
    );
    putValue(
      OnboardingKeys.planEndDate,
      'Plan end',
      planEndDate.value == null ? '' : _formatDate(planEndDate.value!),
    );
    putValue(
      OnboardingKeys.budgetCore,
      'Budget core',
      _parseNumberOrEmpty(budgetCoreCtrl.text),
    );
    putValue(
      OnboardingKeys.budgetCb,
      'Budget CB',
      _parseNumberOrEmpty(budgetCbCtrl.text),
    );
    putValue(
      OnboardingKeys.budgetCapital,
      'Budget capital',
      _parseNumberOrEmpty(budgetCapitalCtrl.text),
    );
    putValue(
      OnboardingKeys.fundingNotToExceed,
      'Funding not-to-exceed',
      _parseNumberOrEmpty(fundingNotToExceedCtrl.text),
    );
    putValue(
      OnboardingKeys.supportCoordinatorName,
      'Support coordinator name',
      scNameCtrl.text.trim(),
    );
    putValue(
      OnboardingKeys.supportCoordinatorPhone,
      'Support coordinator phone',
      scPhoneCtrl.text.trim(),
    );
    putValue(
      OnboardingKeys.supportCoordinatorEmail,
      'Support coordinator email',
      scEmailCtrl.text.trim(),
    );

    final claiming = preferredClaimingMethod.value?.trim();
    if (claiming != null && claiming.isNotEmpty) {
      putValue(
        OnboardingKeys.preferredClaimingMethod,
        'Preferred claiming',
        claiming,
      );
    }
    putValue(
      OnboardingKeys.preferredClaimingOtherDetail,
      'Claiming other detail',
      preferredClaimingOtherCtrl.text.trim(),
    );

    // Booleans always upserted when hydrated (D5=A), including false.
    putValue(
      OnboardingKeys.infoShareConsent,
      'Info share consent',
      infoShareConsent.value,
    );
    putValue(
      OnboardingKeys.specificSupportsConsent,
      'Specific supports consent',
      specificSupportsConsent.value,
    );

    if (jobs.isEmpty) return const [];

    final results = await Future.wait(
      jobs.map((j) async {
        try {
          await j.future;
          return null;
        } catch (_) {
          return j.label;
        }
      }),
    );
    return results.whereType<String>().toList(growable: false);
  }

  Future<bool> uploadNdisPlanPdf({required String clientId}) async {
    errorMessage.value = null;
    final pick = _pickPdfBytes;
    if (pick == null) {
      errorMessage.value = 'PDF picker is not configured.';
      return false;
    }
    isBusy.value = true;
    try {
      final bytes = await pick();
      if (bytes == null) {
        errorMessage.value = 'Select an NDIA plan PDF to upload.';
        return false;
      }
      final pipeline = _pipeline;
      if (pipeline == null) {
        errorMessage.value = 'Document upload is not configured.';
        return false;
      }
      if (!_canUploadDocs()) {
        errorMessage.value =
            'Missing documents.upload / clients.docs.manage permission.';
        return false;
      }
      final doc = await pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'client',
          ownerId: clientId,
          filename: bytes.name,
          contentType: 'application/pdf',
          sizeBytes: bytes.bytes.length,
          category: 'ndis',
        ),
        bytes: bytes.bytes,
      );
      await _repository.upsertProfileFact(
        clientId,
        OnboardingKeys.ndis,
        ProfileFactUpsert(documentId: doc.id),
      );
      ndisPdfOnFile.value = true;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> markConsentComplete({required String clientId}) async {
    errorMessage.value = null;
    isBusy.value = true;
    try {
      await _legalHelper.completeConsent(
        clientId: clientId,
        participantOrRepName: consentSignerNameCtrl.text,
      );
      consentAgreementComplete.value = true;
      return true;
    } on AppFailure catch (e) {
      if (ClientLegalUploadHelper.isConsentLegalUnavailable(e)) {
        errorMessage.value =
            ClientLegalUploadHelper.consentLegalUnavailableMessage;
      } else {
        errorMessage.value = e.message;
      }
      return false;
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> markServiceAgreementComplete({required String clientId}) async {
    errorMessage.value = null;
    isBusy.value = true;
    try {
      await _legalHelper.completeServiceAgreement(clientId: clientId);
      serviceAgreementComplete.value = true;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> markAcknowledgementComplete({required String clientId}) async {
    errorMessage.value = null;
    isBusy.value = true;
    try {
      await _legalHelper.completeAcknowledgement(clientId: clientId);
      acknowledgementComplete.value = true;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  void dispose() {
    planManagerNameCtrl.dispose();
    planManagerPhoneCtrl.dispose();
    planManagerEmailCtrl.dispose();
    budgetCoreCtrl.dispose();
    budgetCbCtrl.dispose();
    budgetCapitalCtrl.dispose();
    fundingNotToExceedCtrl.dispose();
    scNameCtrl.dispose();
    scPhoneCtrl.dispose();
    scEmailCtrl.dispose();
    preferredClaimingOtherCtrl.dispose();
    consentSignerNameCtrl.dispose();
  }

  static ClientProfileFactOut? _fact(ClientProfileBundle b, String key) {
    for (final f in b.facts) {
      if (f.requirementKey == key) return f;
    }
    return null;
  }

  static String? _stringFact(ClientProfileBundle b, String key) {
    final v = _fact(b, key)?.valueJson;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool? _boolFact(ClientProfileBundle b, String key) {
    final v = _fact(b, key)?.valueJson;
    if (v is bool) return v;
    if (v == null) return null;
    final s = v.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }

  static DateTime? _dateFact(ClientProfileBundle b, String key) {
    final s = _stringFact(b, key);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }

  static String _numberText(ClientProfileBundle b, String key) {
    final v = _fact(b, key)?.valueJson;
    if (v == null) return '';
    return v.toString();
  }

  /// Empty string → clear path; number → upsert; invalid → treat as empty.
  static Object _parseNumberOrEmpty(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final n = num.tryParse(t);
    return n ?? '';
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
