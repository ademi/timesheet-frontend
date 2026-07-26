import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../credentials/controllers/credentials_controller.dart';
import '../../credentials/data/models/credential_models.dart';
import '../data/datasources/compliance_remote_datasource.dart';
import '../data/models/compliance_models.dart';
import '../data/repositories/compliance_repository.dart';

enum OnboardingStep { legal, notices, consents, engagement, credentials }

/// Ordered contractor onboarding funnel (design §6.3). Outside tab chrome.
class OnboardingController extends GetxController {
  OnboardingController({required ComplianceRepository repository})
      : _repository = repository;

  final ComplianceRepository _repository;
  final _box = GetStorage();

  static const _funnelDoneKey = 'onboarding_funnel_v1_done';
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
      OnboardingStep.values[stepIndex.value.clamp(0, OnboardingStep.values.length - 1)];

  bool get canAdvanceLegal =>
      requiredDocKeys.every((k) => acceptedDocKeys.contains(k));

  bool get canAdvanceNotices =>
      notices.isEmpty ||
      notices.every((n) => acknowledgedNoticeKeys.contains(n.noticeKey));

  bool get canAdvanceConsents {
    final needed = notices
        .map((n) => n.credentialType)
        .whereType<String>()
        .where(sensitiveCredentialTypes.contains)
        .toSet();
    // No sensitive notices in catalog → nothing to consent in S2.
    if (needed.isEmpty) return true;
    return needed.every(consentedTypes.contains);
  }

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
        await _recordPresentedDoc(doc);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.code == 'counsel_pending_policy' ||
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
        await _recordPresentedNotice(n);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.code == 'counsel_pending_policy'
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
        idempotencyKey:
            _idemKey('presented-notice-${notice.noticeKey}-${notice.version}'),
      );
      presentedNoticeKeys.add(notice.noticeKey);
      final type = notice.credentialType;
      if (type != null &&
          Get.isRegistered<CredentialsController>()) {
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
    } on AppFailure catch (e) {
      errorMessage.value = e.code == 'counsel_pending_policy'
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
        idempotencyKey:
            _idemKey('ack-notice-${notice.noticeKey}-${notice.version}'),
      );
      acknowledgedNoticeKeys.add(notice.noticeKey);
    } on AppFailure catch (e) {
      errorMessage.value = e.code == 'counsel_pending_policy'
          ? 'This legal document is not available yet.'
          : e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> consentToType(String credentialType, {CollectionNotice? notice}) async {
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
        goToStep(OnboardingStep.engagement);
      case OnboardingStep.engagement:
        goToStep(OnboardingStep.credentials);
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
    funnelDoneOverride = true;
    try {
      await _box.write(_funnelDoneKey, true);
    } catch (_) {}
    Get.offAllNamed(AppRoutes.contractorHome);
  }

  void _syncRoute() {
    final route = switch (currentStep) {
      OnboardingStep.legal => AppRoutes.contractorOnboardingLegal,
      OnboardingStep.notices => AppRoutes.contractorOnboardingNotices,
      OnboardingStep.consents => AppRoutes.contractorOnboardingConsents,
      OnboardingStep.engagement => AppRoutes.contractorOnboardingEngagement,
      OnboardingStep.credentials => AppRoutes.contractorOnboardingCredentials,
    };
    if (Get.currentRoute != route) {
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

  /// Test hook — when non-null, bypasses GetStorage.
  static bool? funnelDoneOverride;

  static bool isFunnelDone() {
    if (funnelDoneOverride != null) return funnelDoneOverride!;
    try {
      return GetStorage().read(_funnelDoneKey) == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markFunnelDoneForTests() async {
    funnelDoneOverride = true;
    try {
      await GetStorage().write(_funnelDoneKey, true);
    } catch (_) {}
  }

  static Future<void> clearFunnelDone() async {
    funnelDoneOverride = false;
    try {
      await GetStorage().remove(_funnelDoneKey);
    } catch (_) {}
  }
}
