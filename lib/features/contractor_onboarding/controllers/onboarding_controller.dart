import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../credentials/controllers/credentials_controller.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../engagements/controllers/contractor_engagements_controller.dart';
import '../bindings/onboarding_binding.dart';
import '../data/datasources/compliance_remote_datasource.dart';
import '../data/models/compliance_models.dart';
import '../data/repositories/compliance_repository.dart';
import '../data/onboarding_progress_store.dart';
import '../onboarding_routing.dart';

enum OnboardingStep { legal, notices, consents, engagement, credentials }

/// Ordered contractor onboarding funnel (design §6.3). Outside tab chrome.
class OnboardingController extends GetxController {
  OnboardingController({
    required ComplianceRepository repository,
    OnboardingProgressStore? progressStore,
  }) : _repository = repository,
       _progressStore = progressStore ?? OnboardingProgressStore();

  final ComplianceRepository _repository;
  final OnboardingProgressStore _progressStore;

  static const requiredDocKeys = ['platform_terms', 'privacy_policy'];

  final stepIndex = 0.obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  final legalDocs = <LegalDocumentCurrent>[].obs;
  final acceptedDocKeys = <String>{}.obs;
  final presentedDocKeys = <String>{}.obs;

  final notices = <CollectionNotice>[].obs;
  final acknowledgedNoticeKeys = <String>{}.obs;
  final presentedNoticeKeys = <String>{}.obs;

  final consentedTypes = <String>{}.obs;

  /// Idempotency keys reused on retry for the same logical action.
  final _idempotencyKeys = <String, String>{};

  OnboardingStep get currentStep =>
      OnboardingStep.values[stepIndex.value.clamp(
        0,
        OnboardingStep.values.length - 1,
      )];

  bool get canAdvanceLegal =>
      requiredDocKeys.every((k) => acceptedDocKeys.contains(k));

  bool get canAdvanceNotices =>
      notices.isEmpty ||
      notices.every((n) => acknowledgedNoticeKeys.contains(n.noticeKey));

  bool get canAdvanceConsents {
    final needed =
        notices
            .map((n) => n.credentialType)
            .whereType<String>()
            .where(sensitiveCredentialTypes.contains)
            .toSet();
    // No sensitive notices in catalog → nothing to consent in S2.
    if (needed.isEmpty) return true;
    return needed.every(consentedTypes.contains);
  }

  bool get canAdvanceEngagement {
    if (!Get.isRegistered<ContractorEngagementsController>()) return true;
    final c = Get.find<ContractorEngagementsController>();
    // May continue if nothing invited remains (or no engagements at all).
    return c.invited.isEmpty;
  }

  String? get _contractorId {
    if (!Get.isRegistered<SessionService>()) return null;
    return Get.find<SessionService>().contractorId.value;
  }

  SessionService? get _sessionService =>
      Get.isRegistered<SessionService>() ? Get.find<SessionService>() : null;

  @override
  void onInit() {
    super.onInit();
    loadLegal();
  }

  Future<void> loadLegal() async {
    isLoading.value = true;
    errorMessage.value = null;
    legalDocs.clear();
    try {
      for (final key in requiredDocKeys) {
        final doc = await _repository.getCurrentLegalDocument(key);
        legalDocs.add(doc);
        final acceptedVersion =
            _progressStore.load(_contractorId).acceptedDocVersions[doc.docKey];
        if (acceptedVersion == doc.version) {
          acceptedDocKeys.add(doc.docKey);
        }
        await _recordPresentedDoc(doc);
      }
    } on AppFailure catch (e) {
      errorMessage.value =
          e.code == 'counsel_pending_policy' ||
                  e.code == 'legal_document_unavailable'
              ? 'This legal document is not available yet.'
              : e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadNotices() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.listCollectionNotices(jurisdiction: 'AU');
      notices.assignAll(list);
      for (final n in list) {
        final snapshot = _progressStore.load(_contractorId);
        if (snapshot.acknowledgedNoticeVersions[n.noticeKey] == n.version) {
          acknowledgedNoticeKeys.add(n.noticeKey);
        }
        if (n.credentialType != null &&
            snapshot.consentedTypes.contains(n.credentialType)) {
          consentedTypes.add(n.credentialType!);
        }
        await _recordPresentedNotice(n);
      }
    } on AppFailure catch (e) {
      errorMessage.value =
          e.code == 'counsel_pending_policy'
              ? 'This legal document is not available yet.'
              : e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  String _idemKey(String action) {
    return _idempotencyKeys.putIfAbsent(
      action,
      () => ComplianceRemoteDataSource.newIdempotencyKey(action),
    );
  }

  Future<void> _recordPresentedDoc(LegalDocumentCurrent doc) async {
    if (presentedDocKeys.contains(doc.docKey)) return;
    try {
      await _repository.createLegalEvent(
        LegalEventCreate(
          eventType: 'presented',
          docKey: doc.docKey,
          version: doc.version,
          presentationSource: 'contractor_onboarding',
        ),
        idempotencyKey: _idemKey('presented-doc-${doc.docKey}-${doc.version}'),
      );
      presentedDocKeys.add(doc.docKey);
    } on AppFailure {
      // Non-fatal: user can still attempt accept; server may reject if needed.
    }
  }

  Future<void> _recordPresentedNotice(CollectionNotice notice) async {
    if (presentedNoticeKeys.contains(notice.noticeKey)) return;
    try {
      final event = await _repository.createLegalEvent(
        LegalEventCreate(
          eventType: 'presented',
          noticeKey: notice.noticeKey,
          noticeVersion: notice.version,
          credentialType: notice.credentialType,
          presentationSource: 'contractor_onboarding',
        ),
        idempotencyKey: _idemKey(
          'presented-notice-${notice.noticeKey}-${notice.version}',
        ),
      );
      presentedNoticeKeys.add(notice.noticeKey);
      final type = notice.credentialType;
      if (type != null && Get.isRegistered<CredentialsController>()) {
        Get.find<CredentialsController>().presentedEventIds[type] = event.id;
      }
    } on AppFailure {
      // Non-fatal presentation log.
    }
  }

  Future<void> acceptLegalDoc(LegalDocumentCurrent doc) async {
    if (doc.counselPending) {
      // Still attempt accept in non-prod; API fail-closed in production.
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _repository.createLegalEvent(
        LegalEventCreate(
          eventType: 'accepted',
          docKey: doc.docKey,
          version: doc.version,
          presentationSource: 'contractor_onboarding',
        ),
        idempotencyKey: _idemKey('accepted-doc-${doc.docKey}-${doc.version}'),
      );
      acceptedDocKeys.add(doc.docKey);
      await _progressStore.markAcceptedDocument(
        _contractorId,
        docKey: doc.docKey,
        version: doc.version,
      );
    } on AppFailure catch (e) {
      errorMessage.value =
          e.code == 'counsel_pending_policy'
              ? 'This legal document is not available yet.'
              : e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> acknowledgeNotice(CollectionNotice notice) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _repository.createLegalEvent(
        LegalEventCreate(
          eventType: 'acknowledged',
          noticeKey: notice.noticeKey,
          noticeVersion: notice.version,
          credentialType: notice.credentialType,
          presentationSource: 'contractor_onboarding',
        ),
        idempotencyKey: _idemKey(
          'ack-notice-${notice.noticeKey}-${notice.version}',
        ),
      );
      acknowledgedNoticeKeys.add(notice.noticeKey);
      await _progressStore.markNoticeAcknowledged(
        _contractorId,
        noticeKey: notice.noticeKey,
        version: notice.version,
      );
    } on AppFailure catch (e) {
      errorMessage.value =
          e.code == 'counsel_pending_policy'
              ? 'This legal document is not available yet.'
              : e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> consentToType(
    String credentialType, {
    CollectionNotice? notice,
  }) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _repository.createLegalEvent(
        LegalEventCreate(
          eventType: 'consented',
          noticeKey: notice?.noticeKey,
          noticeVersion: notice?.version,
          credentialType: credentialType,
          dataClass: 'sensitive_credential',
          presentationSource: 'contractor_onboarding',
        ),
        idempotencyKey: _idemKey('consent-$credentialType'),
      );
      consentedTypes.add(credentialType);
      await _progressStore.markConsentRecorded(_contractorId, credentialType);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void goToStep(OnboardingStep step) {
    stepIndex.value = step.index;
    if (step == OnboardingStep.notices && notices.isEmpty) {
      loadNotices();
    }
    _syncRoute();
  }

  Future<void> next() async {
    switch (currentStep) {
      case OnboardingStep.legal:
        if (!canAdvanceLegal) {
          _toast('Accept Platform Terms and Privacy Policy to continue.');
          return;
        }
        goToStep(OnboardingStep.notices);
        await loadNotices();
      case OnboardingStep.notices:
        if (!canAdvanceNotices) {
          _toast('Acknowledge each collection notice to continue.');
          return;
        }
        goToStep(OnboardingStep.consents);
      case OnboardingStep.consents:
        if (!canAdvanceConsents) {
          _toast('Record consent for each sensitive credential type.');
          return;
        }
        goToStep(OnboardingStep.credentials);
        if (Get.isRegistered<CredentialsController>()) {
          await Get.find<CredentialsController>().load();
        }
      case OnboardingStep.engagement:
        if (!canAdvanceEngagement) {
          _toast('Accept each invited engagement before continuing.');
          return;
        }
        goToStep(OnboardingStep.credentials);
        if (Get.isRegistered<CredentialsController>()) {
          await Get.find<CredentialsController>().load();
        }
      case OnboardingStep.credentials:
        await completeFunnel();
    }
  }

  void back() {
    if (stepIndex.value <= 0) return;
    stepIndex.value -= 1;
    _syncRoute();
  }

  Future<void> completeFunnel() async {
    await _progressStore.markCredentialsStepDone(_contractorId);
    final session = _sessionService;
    session?.refreshOnboardingFlags();
    if (session?.needsEngagementWork.value == true) {
      goToStep(OnboardingStep.engagement);
      if (Get.isRegistered<ContractorEngagementsController>()) {
        await Get.find<ContractorEngagementsController>().load();
      }
      return;
    }
    Get.offAllNamed(AppRoutes.contractorHome);
    // After leaving the funnel so a dispose rebuild cannot re-ensure().
    OnboardingBinding.reset();
  }

  void _syncRoute() {
    final route = OnboardingRouting.routeForStep(currentStep);
    if (Get.currentRoute != route) {
      // Replace step URL only — controller stays via permanent registration.
      Get.offNamed(route);
    }
  }

  void _toast(String message) {
    Get.snackbar(
      'Complete this step',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
  }

  OnboardingStep? resolveFirstIncompleteStep() {
    if (!canAdvanceLegal) return OnboardingStep.legal;
    if (!canAdvanceNotices) return OnboardingStep.notices;
    if (!canAdvanceConsents) return OnboardingStep.consents;
    if (!_progressStore.isPlatformComplete(_contractorId)) {
      return OnboardingStep.credentials;
    }
    if (_sessionService?.needsEngagementWork.value == true) {
      return OnboardingStep.engagement;
    }
    return null;
  }

  void navigateToFirstIncompleteStep() {
    final step = resolveFirstIncompleteStep();
    final route =
        step == null
            ? AppRoutes.contractorHome
            : OnboardingRouting.routeForStep(step);
    if (Get.currentRoute != route) Get.offNamed(route);
  }
}
