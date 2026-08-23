import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/ongoing_support_controller.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/job_copy.dart';
import 'package:rostiq/features/jobs/utils/time_window_utils.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeOngoingSupportCreateRequest extends Fake
    implements OngoingSupportCreateRequest {}

class _FakeJobCreateRequest extends Fake implements JobCreateRequest {}

final _now = DateTime.utc(2026, 8, 13, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Lee',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

final _site = ClientSiteOut(
  id: 'site-1',
  tenantId: 'tenant-1',
  clientId: 'client-1',
  name: 'Home',
  geofenceRadiusM: 100,
  isPrimary: true,
  createdAt: _now,
  updatedAt: _now,
);

const _branch = BranchOut(id: 'branch-1', name: 'North');

final _fakeOut = OngoingSupportOut(
  job: JobOut(
    id: 'job-created',
    tenantId: 'tenant-1',
    kind: 'standing',
    status: 'open',
    title: 'Sam Lee support',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: _now,
    updatedAt: _now,
  ),
  rule: RecurrenceRuleOut(
    id: 'rule-1',
    tenantId: 'tenant-1',
    jobId: 'job-created',
    requiredSlots: 1,
    rrule: 'FREQ=WEEKLY;BYDAY=MO',
    dtstart: _now,
    timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
    isActive: true,
    createdAt: _now,
    updatedAt: _now,
  ),
  horizon: HorizonOut.empty,
);

void main() {
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockSessionService session;
  late List<(String route, dynamic arguments)> navigations;
  late OngoingSupportController controller;

  setUpAll(() {
    registerFallbackValue(_FakeOngoingSupportCreateRequest());
    registerFallbackValue(_FakeJobCreateRequest());
  });

  setUp(() async {
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();
    when(() => session.tenantId).thenReturn(RxnString());
    navigations = [];
    when(() => clients.listSites(any())).thenAnswer((_) async => [_site]);
    when(() => jobs.listBranches()).thenAnswer((_) async => [_branch]);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
    controller = OngoingSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      session: session,
      client: _client,
      onNavigate: (route, arguments) => navigations.add((route, arguments)),
    );
    await controller.load();
  });

  tearDown(Get.reset);

  test(
    'submit posts unfilled ongoing support and does not call createJob',
    () async {
      when(
        () => jobs.createOngoingSupport(any()),
      ).thenAnswer((_) async => _fakeOut);
      await controller.submit();
      verify(() => jobs.createOngoingSupport(any())).called(1);
      verifyNever(() => jobs.createJob(any()));
    },
  );

  test('submit blocked when client has no sites and mode is home', () async {
    controller.sites.clear();
    await controller.submit();
    expect(controller.errorMessage.value, contains('Add a site'));
    verifyNever(() => jobs.createOngoingSupport(any()));
  });

  test('submit with branch posts branchId and no clientSiteId', () async {
    controller.locationMode.value = 'branch';
    controller.selectedBranchId.value = 'branch-1';
    when(
      () => jobs.createOngoingSupport(any()),
    ).thenAnswer((_) async => _fakeOut);
    await controller.submit();
    final captured =
        verify(() => jobs.createOngoingSupport(captureAny())).captured.single
            as OngoingSupportCreateRequest;
    expect(captured.branchId, 'branch-1');
    expect(captured.clientSiteId, isNull);
  });

  test('branch mode blocked when branches empty', () async {
    controller.locationMode.value = 'branch';
    controller.branches.clear();
    await controller.submit();
    expect(controller.errorMessage.value, contains('branch'));
    verifyNever(() => jobs.createOngoingSupport(any()));
  });

  test(
    'defaults unfilled person, client title, and a 14-day horizon',
    () async {
      when(
        () => jobs.createOngoingSupport(any()),
      ).thenAnswer((_) async => _fakeOut);
      await controller.submit();
      final captured =
          verify(() => jobs.createOngoingSupport(captureAny())).captured.single
              as OngoingSupportCreateRequest;
      expect(captured.contractorId, isNull);
      expect(captured.title, defaultOngoingTitle('Sam Lee'));
      expect(captured.clientSiteId, 'site-1');
      expect(captured.branchId, isNull);
      expect(captured.horizonTo.difference(captured.horizonFrom).inDays, 14);
    },
  );

  test('submit lands on roster with skipHorizonOnce and ids', () async {
    when(
      () => jobs.createOngoingSupport(any()),
    ).thenAnswer((_) async => _fakeOut);
    await controller.submit();
    expect(navigations, hasLength(1));
    expect(navigations.single.$1, AppRoutes.staffVisits);
    expect(navigations.single.$2, {
      'skipHorizonOnce': true,
      'job_id': 'job-created',
      'client_id': 'client-1',
    });
  });

  test('branch load failure clears branches', () async {
    when(() => jobs.listBranches()).thenThrow(Exception('offline'));
    await controller.load();
    expect(controller.branches, isEmpty);
  });

  test('submit blocked for overnight end time', () async {
    controller.endTimeCtrl.text = '00:00';
    await controller.submit();
    expect(controller.errorMessage.value, contains('Overnight'));
    verifyNever(() => jobs.createOngoingSupport(any()));
  });

  test('submit surfaces friendly message when standing job exists', () async {
    when(() => jobs.createOngoingSupport(any())).thenThrow(
      const AppFailure(
        code: 'standing_job_exists',
        message:
            'This client already has ongoing support. Open it, or book one extra session.',
        presentation: AppFailurePresentation.inline,
      ),
    );
    await controller.submit();
    expect(
      controller.errorMessage.value,
      contains('already has ongoing support'),
    );
  });

  test('defaults end date one year after start', () async {
    when(
      () => jobs.createOngoingSupport(any()),
    ).thenAnswer((_) async => _fakeOut);
    final start = DateTime(2026, 6, 1);
    controller.startDate.value = start;
    controller.endDate.value = defaultRecurrenceEndDate(start);
    await controller.submit();
    final captured =
        verify(() => jobs.createOngoingSupport(captureAny())).captured.single
            as OngoingSupportCreateRequest;
    expect(captured.until, isNotNull);
    expect(captured.until!.year, 2027);
    expect(captured.until!.month, 6);
    expect(captured.until!.day, 1);
  });

  test('submit includes optional support item pair', () async {
    controller.setSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );
    when(
      () => jobs.createOngoingSupport(any()),
    ).thenAnswer((_) async => _fakeOut);
    await controller.submit();
    final captured =
        verify(() => jobs.createOngoingSupport(captureAny())).captured.single
            as OngoingSupportCreateRequest;
    expect(captured.supportItemCode, '01_011_0107_1_1');
    expect(captured.supportItemName, 'Self care');
  });
}
