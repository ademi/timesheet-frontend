import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/contractor_onboarding/controllers/onboarding_controller.dart';
import 'package:rostiq/features/contractor_onboarding/data/models/compliance_models.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/contractor_onboarding/views/onboarding_funnel_view.dart';

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

CollectionNotice _notice(String key) => CollectionNotice(
  noticeKey: key,
  version: '1',
  contentMd: 'Notice body for $key',
  contentHash: 'hash',
  purpose: 'eligibility',
  legalOrPolicyBasis: 'policy',
  consequencesOfRefusal: 'cannot proceed',
  retentionSummary: 'kept',
  counselPending: false,
  effectiveAt: DateTime.utc(2026, 1, 1),
  jurisdiction: 'AU',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const LegalEventCreate(eventType: 'presented'));
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  testWidgets(
    'notices step shows N-of-M and disables Continue when incomplete',
    (tester) async {
      final repo = _MockComplianceRepository();
      when(() => repo.getCurrentLegalDocument(any())).thenAnswer(
        (_) async => LegalDocumentCurrent(
          docKey: 'platform_terms',
          version: '1',
          contentMd: 'Body',
          contentHash: 'hash',
          effectiveAt: DateTime.utc(2026, 1, 1),
          counselPending: false,
        ),
      );
      when(
        () => repo.createLegalEvent(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => LegalEventResult(
          id: 'evt-1',
          eventType: 'presented',
          createdAt: DateTime.utc(2026, 7, 30),
        ),
      );

      final controller = OnboardingController(repository: repo);
      Get.put<OnboardingController>(controller, permanent: true);

      controller.stepIndex.value = OnboardingStep.notices.index;
      controller.notices.assignAll([
        _notice('n1'),
        _notice('n2'),
        _notice('n3'),
        _notice('n4'),
      ]);
      controller.acknowledgedNoticeKeys.addAll({'n1', 'n2'});

      await tester.pumpWidget(
        const GetMaterialApp(home: OnboardingFunnelView()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acknowledged 2 of 4'), findsOneWidget);

      final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
      expect(continueButton, findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(continueButton).onPressed,
        isNull,
        reason: 'Continue must be disabled until all notices are acknowledged',
      );
    },
  );
}
