import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

VisitOut _visit() {
  final t = DateTime.utc(2026, 8, 12, 9);
  return VisitOut(
    id: 'v1',
    tenantId: 't',
    jobId: 'j',
    contractorId: 'c',
    scheduledStart: t,
    scheduledEnd: t.add(const Duration(hours: 1)),
    status: 'scheduled',
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockJobsRepository jobs;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    visits = _MockVisitsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <VisitOut>[]);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  test('onInit with skipBoardLoad does not call listVisits', () async {
    Get.routing.args = {
      'visit': _visit(),
      'skipBoardLoad': true,
    };
    Get.put(
      StaffVisitsController(
        repository: visits,
        jobsRepository: jobs,
        session: session,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    );
  });

  test('shiftRange after skipBoardLoad still calls listVisits', () async {
    final c = StaffVisitsController(
      repository: visits,
      jobsRepository: jobs,
      session: session,
    );
    Get.put(c);
    Get.routing.args = {'skipBoardLoad': true, 'visit': _visit()};
    c.applyRouteArgs();
    c.shiftRange(1);
    await Future<void>.delayed(Duration.zero);
    verify(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  test('applyRouteArgs with VisitOut clears skipBoardLoad', () async {
    final c = StaffVisitsController(
      repository: visits,
      jobsRepository: jobs,
      session: session,
    );
    Get.put(c);
    Get.routing.args = {'skipBoardLoad': true, 'visit': _visit()};
    c.applyRouteArgs();
    Get.routing.args = _visit();
    c.applyRouteArgs();
    await c.load();
    verify(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });

  test('ensureBoardLoaded clears skip and calls listVisits', () async {
    final c = StaffVisitsController(
      repository: visits,
      jobsRepository: jobs,
      session: session,
    );
    Get.put(c);
    Get.routing.args = {'skipBoardLoad': true, 'visit': _visit()};
    c.applyRouteArgs();
    await c.ensureBoardLoaded();
    verify(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });
}
