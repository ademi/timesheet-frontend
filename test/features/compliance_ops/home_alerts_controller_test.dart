import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/compliance_ops/data/models/compliance_ops_models.dart';
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
      () => repository.listNotificationEvents(limit: 20),
    ).thenAnswer((_) async => []);
    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  SharingAccessRequestOut pendingRequest({
    String id = 'req-1',
    String engagementId = 'engagement-1',
    String tenantId = 'tenant-1',
  }) {
    return SharingAccessRequestOut(
      id: id,
      tenantId: tenantId,
      engagementId: engagementId,
      contractorId: 'contractor-1',
      requestedByUserId: 'user-1',
      status: 'pending',
      credentialTypes: const [],
      allowSourceEvidence: true,
      createdAt: DateTime.utc(2026, 7, 31),
    );
  }

  test('contractor load fetches pending sharing access requests', () async {
    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => [pendingRequest()]);

    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      showSnack: (_, __) {},
    );
    await controller.load();

    expect(controller.pendingSharingRequests, hasLength(1));
    expect(controller.pendingSharingRequests.single.id, 'req-1');
    verify(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).called(1);
  });

  test('staff load does not fetch sharing access requests', () async {
    when(() => session.isStaff).thenReturn(true);
    when(() => session.isContractor).thenReturn(false);

    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      showSnack: (_, __) {},
    );
    await controller.load();

    expect(controller.pendingSharingRequests, isEmpty);
    verifyNever(
      () => repository.listSharingAccessRequests(
        status: any(named: 'status'),
      ),
    );
  });

  test('approveSharingRequest posts approve and refreshes pending list', () async {
    engagements.assignAll([
      const EngagementSummaryModel(
        id: 'engagement-1',
        tenantId: 'tenant-1',
        tenantName: 'Acme Care',
        status: 'active',
      ),
    ]);
    final req = pendingRequest();
    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => [req]);
    when(
      () => repository.approveSharingAccessRequest('req-1'),
    ).thenAnswer((_) async => req.copyWith(status: 'approved'));

    final snacks = <String>[];
    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      showSnack: (title, message) => snacks.add('$title|$message'),
    );
    await controller.load();

    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => []);

    final ok = await controller.approveSharingRequest(req);

    expect(ok, isTrue);
    verify(() => repository.approveSharingAccessRequest('req-1')).called(1);
    expect(controller.pendingSharingRequests, isEmpty);
    expect(
      snacks.single,
      'Access approved|Credentials shared with Acme Care.',
    );
  });

  test('tenantLabelFor resolves tenant name from session engagements', () {
    engagements.assignAll([
      const EngagementSummaryModel(
        id: 'engagement-1',
        tenantId: 'tenant-1',
        tenantName: 'Acme Care',
        status: 'active',
      ),
    ]);
    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      showSnack: (_, __) {},
    );

    expect(controller.tenantLabelFor(pendingRequest()), 'Acme Care');
  });
}
