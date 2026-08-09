import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/compliance_ops/controllers/notifications_feed_controller.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/compliance_ops/views/home_alerts_view.dart';

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockComplianceOpsRepository repository;
  late _MockSessionService session;
  late RxList<EngagementSummaryModel> engagements;

  setUp(() {
    Get.testMode = true;
    repository = _MockComplianceOpsRepository();
    session = _MockSessionService();
    engagements = <EngagementSummaryModel>[].obs;
    when(() => session.isStaff).thenReturn(false);
    when(() => session.isContractor).thenReturn(true);
    when(() => session.needsDocsAttention).thenReturn(false);
    when(() => session.hasPermission(any())).thenReturn(false);
    when(() => session.engagements).thenReturn(engagements);
    when(
      () => repository.listNotificationEvents(limit: any(named: 'limit')),
    ).thenAnswer((_) async => []);
    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => []);
    Get.put(NotificationsFeedController(repository: repository));
  });

  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester) async {
    Get.put(
      HomeAlertsController(
        repository: repository,
        session: session,
        showSnack: (_, __) {},
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: HomeAlertsView()));
    await tester.pump();
  }

  testWidgets(
    'shows a credentials CTA for contractors with pending documents',
    (tester) async {
      when(() => session.isStaff).thenReturn(false);
      when(() => session.isContractor).thenReturn(true);
      when(() => session.needsDocsAttention).thenReturn(true);
      engagements.assignAll([
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
      expect(find.byTooltip('Notifications'), findsOneWidget);
    },
  );

  testWidgets('hides the documents banner on staff home', (tester) async {
    when(() => session.isStaff).thenReturn(true);
    when(() => session.isContractor).thenReturn(false);
    when(() => session.needsDocsAttention).thenReturn(true);
    engagements.assignAll([
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
    expect(find.byTooltip('Notifications'), findsOneWidget);
  });
}
