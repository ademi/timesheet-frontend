import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/contractor_onboarding/controllers/onboarding_controller.dart';
import 'package:rostiq/features/contractor_onboarding/data/models/compliance_models.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';
import 'package:rostiq/features/contractor_onboarding/views/onboarding_funnel_view.dart';

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

LegalDocumentCurrent _doc(String key) => LegalDocumentCurrent(
  docKey: key,
  version: '1',
  contentMd: 'Body',
  contentHash: 'hash',
  effectiveAt: DateTime.utc(2026, 1, 1),
  counselPending: false,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const LegalEventCreate(eventType: 'consented'));
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  testWidgets(
    'consents checkbox shows checked after recording consent',
    (tester) async {
      final repo = _MockComplianceRepository();
      when(() => repo.getCurrentLegalDocument(any())).thenAnswer(
        (invocation) async =>
            _doc(invocation.positionalArguments.first as String),
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
      await tester.pumpAndSettle();

      expect(controller.errorMessage.value, isNull);

      controller.stepIndex.value = OnboardingStep.consents.index;
      controller.notices.assignAll([
        CollectionNotice(
          noticeKey: 'police_check_notice',
          version: '1',
          contentMd: 'Notice',
          contentHash: 'hash',
          purpose: 'eligibility',
          legalOrPolicyBasis: 'policy',
          consequencesOfRefusal: 'cannot proceed',
          retentionSummary: 'kept',
          counselPending: false,
          effectiveAt: DateTime.utc(2026, 1, 1),
          credentialType: 'police_check',
          jurisdiction: 'AU',
        ),
      ]);

      await tester.pumpWidget(
        const GetMaterialApp(home: OnboardingFunnelView()),
      );
      await tester.pumpAndSettle();

      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);
      expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);

      when(
        () => repo.createLegalEvent(
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
        ),
      ).thenAnswer(
        (_) async => LegalEventResult(
          id: 'evt-consent',
          eventType: 'consented',
          createdAt: DateTime.utc(2026, 7, 30),
        ),
      );

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(controller.consentedTypes.contains('police_check'), isTrue);
      expect(
        tester.widget<CheckboxListTile>(checkbox).value,
        isTrue,
        reason:
            'Checkbox must rebuild from consentedTypes; nested Builder '
            'breaks Obx tracking',
      );
    },
  );
}
