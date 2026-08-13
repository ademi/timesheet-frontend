import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

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

StaffVisitsController _controller({
  required _MockVisitsRepository visits,
  required _MockShiftsRepository shifts,
  required _MockJobsRepository jobs,
  required _MockEngagementsRepository engagements,
  required _MockSessionService session,
}) {
  return StaffVisitsController(
    repository: visits,
    shiftsRepository: shifts,
    jobsRepository: jobs,
    engagementsRepository: engagements,
    session: session,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
    registerFallbackValue(_FakeHorizonRequest());
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer((_) async => <ShiftOut>[]);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);
    when(
      () => engagements.listTenantEngagements(),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  test('onInit does not call listShifts', () async {
    Get.routing.args = {'visit': _visit()};
    Get.put(
      _controller(
        visits: visits,
        shifts: shifts,
        jobs: jobs,
        engagements: engagements,
        session: session,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    );
  });

  test('shiftRange calls listShifts', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      session: session,
    );
    Get.put(c);
    c.shiftRange(1);
    await Future<void>.delayed(Duration.zero);
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
  });

  test('load calls listShifts', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      session: session,
    );
    Get.put(c);
    await c.load();
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
  });

  test('ensureBoardLoaded calls listShifts', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      session: session,
    );
    Get.put(c);
    await c.ensureBoardLoaded();
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
  });

  test('applyRouteArgs sets job filter and pending create from map', () {
    Get.routing.args = {'job_id': 'job-standing', 'create': true};
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      session: session,
    );
    c.applyRouteArgs();
    expect(c.jobIdFilter.value, 'job-standing');
    expect(c.consumePendingCreateShift(), isTrue);
    expect(c.consumePendingCreateShift(), isFalse);
  });
}
