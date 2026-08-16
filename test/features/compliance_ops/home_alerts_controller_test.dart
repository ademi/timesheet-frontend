import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/compliance_ops/controllers/notifications_feed_controller.dart';
import 'package:rostiq/features/compliance_ops/data/models/compliance_ops_models.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/compliance_ops/views/home_alerts_view.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

void main() {
  late _MockComplianceOpsRepository repository;
  late _MockSessionService session;
  late RxList<EngagementSummaryModel> engagements;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

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

  test('second load without force skips network when cache is fresh', () async {
    when(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).thenAnswer((_) async => [pendingRequest()]);

    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      showSnack: (_, __) {},
    );
    await controller.load();
    await controller.load();
    await controller.load(force: true);

    verify(
      () => repository.listSharingAccessRequests(status: 'pending'),
    ).called(2);
  });

  test('staff load aggregates dashboard stats from list APIs', () async {
    when(() => session.isStaff).thenReturn(true);
    when(() => session.isContractor).thenReturn(false);
    when(() => session.hasPermission(any())).thenAnswer((invocation) {
      final perm = invocation.positionalArguments.first as String;
      return perm.contains('clients') ||
          perm.contains('contractors') ||
          perm.contains('jobs') ||
          perm.contains('visits');
    });

    final clients = _MockClientsRepository();
    final workforce = _MockEngagementsRepository();
    final jobs = _MockJobsRepository();
    final visits = _MockVisitsRepository();

    when(() => clients.listClients()).thenAnswer(
      (_) async => [
        ClientOut(
          id: 'c1',
          tenantId: 't1',
          fullName: 'Alice',
          status: 'active',
          metadata: const {},
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        ClientOut(
          id: 'c2',
          tenantId: 't1',
          fullName: 'Bob',
          status: 'inactive',
          metadata: const {},
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    when(() => workforce.listTenantEngagements()).thenAnswer(
      (_) async => [
        EngagementOut(
          id: 'e1',
          tenantId: 't1',
          contractorId: 'x1',
          status: 'active',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        EngagementOut(
          id: 'e2',
          tenantId: 't1',
          contractorId: 'x2',
          status: 'invited',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        EngagementOut(
          id: 'e3',
          tenantId: 't1',
          contractorId: 'x3',
          status: 'pending_docs',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );
    when(() => jobs.listJobs()).thenAnswer(
      (_) async => [
        JobOut(
          id: 'j1',
          tenantId: 't1',
          kind: 'standing',
          status: 'open',
          title: 'Job 1',
          geofenceRadiusM: 100,
          geofenceMode: 'informational',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        JobOut(
          id: 'j2',
          tenantId: 't1',
          kind: 'ad_hoc',
          status: 'closed',
          title: 'Job 2',
          geofenceRadiusM: 100,
          geofenceMode: 'informational',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 10);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => [
        VisitOut(
          id: 'v1',
          tenantId: 't1',
          jobId: 'j1',
          contractorId: 'x1',
          scheduledStart: todayStart,
          scheduledEnd: todayStart.add(const Duration(hours: 1)),
          status: 'scheduled',
          source: 'manual',
          geofenceRadiusM: 100,
          geofenceMode: 'informational',
          paymentStatus: 'unpaid',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        VisitOut(
          id: 'v2',
          tenantId: 't1',
          jobId: 'j1',
          contractorId: 'x1',
          scheduledStart: todayStart.add(const Duration(hours: 2)),
          scheduledEnd: todayStart.add(const Duration(hours: 3)),
          status: 'completed',
          source: 'manual',
          geofenceRadiusM: 100,
          geofenceMode: 'informational',
          paymentStatus: 'unpaid',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ],
    );

    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      clientsRepository: clients,
      engagementsRepository: workforce,
      jobsRepository: jobs,
      visitsRepository: visits,
      showSnack: (_, __) {},
    );
    await controller.load();

    final stats = controller.stats.value!;
    expect(stats.clientsTotal, 2);
    expect(stats.clientsActive, 1);
    expect(stats.contractorsTotal, 3);
    expect(stats.contractorsActive, 1);
    expect(stats.contractorsInvited, 1);
    expect(stats.contractorsPendingDocs, 1);
    expect(stats.jobsTotal, 2);
    expect(stats.jobsOpen, 1);
    expect(stats.visitsToday, 2);
    expect(stats.visitsScheduledToday, 1);
    expect(stats.visitsCompletedToday, 1);
    expect(stats.visitsThisWeek, 2);
  });

  test('home refresh also refreshes notifications feed', () async {
    final feed = NotificationsFeedController(repository: repository);
    Get.put(feed);

    final controller = HomeAlertsController(
      repository: repository,
      session: session,
      notificationsFeed: feed,
      showSnack: (_, __) {},
    );
    await controller.load();

    verify(
      () => repository.listNotificationEvents(limit: any(named: 'limit')),
    ).called(greaterThanOrEqualTo(1));
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
