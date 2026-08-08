import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/contractor_onboarding/controllers/onboarding_controller.dart';
import 'package:rostiq/features/contractor_onboarding/data/models/compliance_models.dart';
import 'package:rostiq/features/contractor_onboarding/data/onboarding_progress_store.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokenStorage extends Fake implements TokenStorage {
  @override
  JwtClaims? get jwtClaims => null;
}

void main() {
  late Directory storageDirectory;
  late OnboardingProgressStore progressStore;
  late SessionService sessionService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'rostiq_onboarding_controller_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return storageDirectory.path;
          }
          return null;
        });
    await GetStorage.init();
  });

  tearDownAll(() async {
    await storageDirectory.delete(recursive: true);
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    progressStore = OnboardingProgressStore();
    sessionService = SessionService(
      tokenStorage: _FakeTokenStorage(),
      authRepository: _MockAuthRepository(),
      onboardingProgressStore: progressStore,
    );
    sessionService.actorType.value = 'contractor';
    sessionService.contractorId.value = 'contractor-a';
    Get.put<SessionService>(sessionService);
  });

  tearDown(Get.reset);

  void setEngagementStatus(String status) {
    sessionService.engagements.assignAll([
      EngagementSummaryModel(
        id: 'e1',
        tenantId: 't1',
        tenantName: 'Acme',
        status: status,
      ),
    ]);
    sessionService.refreshOnboardingFlags();
  }

  test(
    'resolveFirstIncompleteStep skips legal when already accepted',
    () async {
      await progressStore.markAcceptedDocument(
        'contractor-a',
        docKey: 'platform_terms',
        version: 'v1',
      );
      await progressStore.markAcceptedDocument(
        'contractor-a',
        docKey: 'privacy_policy',
        version: 'v1',
      );
      setEngagementStatus('invited');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );

      expect(
        controller.resolveFirstIncompleteStep(),
        isNot(OnboardingStep.legal),
      );
    },
  );

  test(
    'invited engagement still resolves to engagement step when platform done',
    () async {
      await progressStore.markPlatformComplete('contractor-a');
      setEngagementStatus('invited');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );

      expect(
        controller.resolveFirstIncompleteStep(),
        OnboardingStep.engagement,
      );
    },
  );

  test(
    'does not resolve funnel step when platform complete and status is pending_docs',
    () async {
      await progressStore.markPlatformComplete('contractor-a');
      setEngagementStatus('pending_docs');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );

      expect(controller.resolveFirstIncompleteStep(), isNull);
    },
  );

  test(
    'completeFunnel exits to home when accepted (pending_docs), not engagement',
    () async {
      await progressStore.markPlatformComplete('contractor-a');
      setEngagementStatus('pending_docs');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );
      controller.stepIndex.value = OnboardingStep.consents.index;

      await controller.completeFunnel();

      // Must not bounce back to accept; GetX test mode may leave currentRoute empty.
      expect(controller.currentStep, isNot(OnboardingStep.engagement));
      expect(progressStore.isPlatformComplete('contractor-a'), isTrue);
    },
  );

  test(
    'engagement next exits the funnel after all invites are accepted',
    () async {
      await progressStore.markPlatformComplete('contractor-a');
      setEngagementStatus('pending_docs');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );
      controller.stepIndex.value = OnboardingStep.engagement.index;

      await controller.next();

      // Must not advance into the removed credentials step.
      expect(controller.currentStep, isNot(OnboardingStep.credentials));
    },
  );

  test(
    'completeFunnel returns to engagement when an invite is still open',
    () async {
      await progressStore.markPlatformComplete('contractor-a');
      setEngagementStatus('invited');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );
      controller.stepIndex.value = OnboardingStep.consents.index;

      await controller.completeFunnel();

      expect(controller.currentStep, OnboardingStep.engagement);
    },
  );

  test(
    'resolveFirstIncompleteStep never returns credentials',
    () async {
      await progressStore.markAcceptedDocument(
        'contractor-a',
        docKey: 'platform_terms',
        version: 'v1',
      );
      await progressStore.markAcceptedDocument(
        'contractor-a',
        docKey: 'privacy_policy',
        version: 'v1',
      );
      setEngagementStatus('invited');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );
      // Notices/consents empty → advanceable; platform flag still false.
      expect(
        controller.resolveFirstIncompleteStep(),
        OnboardingStep.engagement,
      );
      expect(
        controller.resolveFirstIncompleteStep(),
        isNot(OnboardingStep.credentials),
      );
    },
  );

  test(
    'active engagement without local flag skips platform funnel',
    () async {
      setEngagementStatus('active');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );

      expect(controller.resolveFirstIncompleteStep(), isNull);
      expect(progressStore.isPlatformComplete('contractor-a'), isTrue);
    },
  );

  test('clears a previous error when navigating to another step', () {
    final controller = OnboardingController(
      repository: _MockComplianceRepository(),
      progressStore: progressStore,
    );
    controller.errorMessage.value = 'This legal document is not available yet.';

    controller.goToStep(OnboardingStep.engagement);

    expect(controller.errorMessage.value, isNull);
    expect(controller.currentStep, OnboardingStep.engagement);
  });

  test('reuses loaded notices until explicitly refreshed', () async {
    final repository = _MockComplianceRepository();
    final controller = OnboardingController(
      repository: repository,
      progressStore: progressStore,
    );
    when(
      () => repository.listCollectionNotices(jurisdiction: 'AU'),
    ).thenAnswer((_) async => const []);

    await controller.loadNotices();
    await controller.loadNotices();

    verify(
      () => repository.listCollectionNotices(jurisdiction: 'AU'),
    ).called(1);
  });

  CollectionNotice notice(String key) => CollectionNotice(
        noticeKey: key,
        version: '1',
        contentMd: 'Body',
        contentHash: 'hash',
        purpose: 'eligibility',
        legalOrPolicyBasis: 'policy',
        consequencesOfRefusal: 'cannot proceed',
        retentionSummary: 'kept',
        counselPending: false,
        effectiveAt: DateTime.utc(2026, 1, 1),
        jurisdiction: 'AU',
      );

  test(
    'when 2 of 4 notices acknowledged, counts and canAdvanceNotices reflect N-of-M',
    () {
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );
      controller.notices.assignAll([
        notice('n1'),
        notice('n2'),
        notice('n3'),
        notice('n4'),
      ]);
      controller.acknowledgedNoticeKeys.addAll({'n1', 'n2'});
      controller.stepIndex.value = OnboardingStep.notices.index;

      expect(controller.noticesAcknowledgedCount, 2);
      expect(controller.noticesTotalCount, 4);
      expect(controller.canAdvanceNotices, isFalse);
      expect(controller.canAdvanceCurrentStep, isFalse);

      controller.acknowledgedNoticeKeys.addAll({'n3', 'n4'});
      expect(controller.noticesAcknowledgedCount, 4);
      expect(controller.canAdvanceNotices, isTrue);
      expect(controller.canAdvanceCurrentStep, isTrue);
    },
  );
}
