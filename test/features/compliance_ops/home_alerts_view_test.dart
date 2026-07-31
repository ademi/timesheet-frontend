import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/compliance_ops/views/home_alerts_view.dart';
import 'package:rostiq/features/contractor_onboarding/data/onboarding_progress_store.dart';

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokenStorage extends Fake implements TokenStorage {
  @override
  JwtClaims? get jwtClaims => null;
}

void main() {
  late _MockComplianceOpsRepository repository;
  late SessionService session;

  setUp(() {
    Get.testMode = true;
    repository = _MockComplianceOpsRepository();
    session = SessionService(
      tokenStorage: _FakeTokenStorage(),
      authRepository: _MockAuthRepository(),
      onboardingProgressStore: OnboardingProgressStore(),
    );
    when(
      () => repository.listNotificationEvents(limit: 20),
    ).thenAnswer((_) async => []);
    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester) async {
    Get.put(HomeAlertsController(repository: repository, session: session));
    await tester.pumpWidget(const GetMaterialApp(home: HomeAlertsView()));
    await tester.pump();
  }

  testWidgets(
    'shows a credentials CTA for contractors with pending documents',
    (tester) async {
      session.actorType.value = 'contractor';
      session.engagements.assignAll([
        const EngagementSummaryModel(
          id: 'engagement-1',
          tenantId: 'tenant-1',
          tenantName: 'Acme',
          status: 'pending_docs',
        ),
      ]);

      await pumpHome(tester);

      expect(
        find.text(
          'Documents still needed for an engagement. '
          'Upload required credentials to continue.',
        ),
        findsOneWidget,
      );
      expect(find.text('Upload credentials'), findsOneWidget);
    },
  );

  testWidgets('hides the documents banner on staff home', (tester) async {
    session.actorType.value = 'tenant_member';
    session.engagements.assignAll([
      const EngagementSummaryModel(
        id: 'engagement-1',
        tenantId: 'tenant-1',
        tenantName: 'Acme',
        status: 'pending_docs',
      ),
    ]);

    await pumpHome(tester);

    expect(
      find.text(
        'Documents still needed for an engagement. '
        'Upload required credentials to continue.',
      ),
      findsNothing,
    );
  });
}
