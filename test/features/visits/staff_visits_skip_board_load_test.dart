import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

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
  required _MockClientsRepository clients,
  required _MockSessionService session,
}) {
  return StaffVisitsController(
    repository: visits,
    shiftsRepository: shifts,
    jobsRepository: jobs,
    engagementsRepository: engagements,
    clientsRepository: clients,
    session: session,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockClientsRepository clients;
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
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        participantId: any(named: 'participantId'),
      ),
    ).thenAnswer((_) async => <ShiftOut>[]);
    when(
      () => visits.fetchRosterOverlay(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => const RosterOverlayOut(contractors: []));
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
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
        clients: clients,
        session: session,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        participantId: any(named: 'participantId'),
      ),
    );
  });

  test('shiftRange calls listShifts', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
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
        participantId: any(named: 'participantId'),
      ),
    ).called(1);
  });

  test('load calls listShifts', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
    );
    Get.put(c);
    await c.load();
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        participantId: any(named: 'participantId'),
      ),
    ).called(1);
  });

  test('ensureBoardLoaded calls listShifts', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
    );
    Get.put(c);
    await c.ensureBoardLoaded();
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        participantId: any(named: 'participantId'),
      ),
    ).called(1);
  });

  test('stale load does not overwrite newer week after shiftRange', () async {
    final t = DateTime.utc(2026, 10, 11, 9);
    final kept = ShiftOut(
      id: 'shift-oct11',
      tenantId: 't',
      jobId: 'j',
      jobTitle: 'SIL',
      scheduledStart: t,
      scheduledEnd: t.add(const Duration(hours: 2)),
      requiredSlots: 1,
      openSlots: 1,
      status: 'published',
      createdAt: t,
      updatedAt: t,
    );
    final first = Completer<List<ShiftOut>>();
    final second = Completer<List<ShiftOut>>();
    var call = 0;
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        participantId: any(named: 'participantId'),
      ),
    ).thenAnswer((_) {
      call += 1;
      return call == 1 ? first.future : second.future;
    });
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        includeNested: any(named: 'includeNested'),
      ),
    ).thenAnswer((_) async => const <VisitOut>[]);

    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
    );
    Get.put(c);

    final older = c.load();
    c.shiftRange(7);
    // Newer week resolves first with the Oct 11 shift.
    second.complete([kept]);
    await Future<void>.delayed(Duration.zero);
    expect(c.shifts.map((s) => s.id), ['shift-oct11']);

    // Slower older week must not clear the board.
    first.complete(const <ShiftOut>[]);
    await older;
    expect(c.shifts.map((s) => s.id), ['shift-oct11']);
  });

  test('second ensureBoardLoaded keeps navigated week', () async {
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
    );
    Get.put(c);
    await c.ensureBoardLoaded();
    final afterNav = c.rangeStart.value.add(const Duration(days: 7));
    c.shiftRange(7);
    await Future<void>.delayed(Duration.zero);
    expect(c.rangeStart.value, afterNav);

    await c.ensureBoardLoaded();
    expect(c.rangeStart.value, afterNav);
  });

  test('revealDraftOnBoard sets Unpublished and aligns week', () async {
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        includeNested: any(named: 'includeNested'),
      ),
    ).thenAnswer((_) async => const <VisitOut>[]);
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
    );
    Get.put(c);
    // Sun 11 Oct 2026 09:00 UTC → week Monday 5 Oct
    c.revealDraftOnBoard(DateTime.utc(2026, 10, 11, 9));
    await Future<void>.delayed(Duration.zero);
    expect(c.statusFilter.value, 'draft');
    expect(c.rangeStart.value.weekday, DateTime.monday);
    expect(c.rangeStart.value.day, 5);
    expect(c.rangeStart.value.month, 10);
  });

  test('applyRouteArgs sets job filter and pending create from map', () {
    Get.routing.args = {'job_id': 'job-standing', 'create': true};
    final c = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
    );
    c.applyRouteArgs();
    expect(c.jobIdFilter.value, 'job-standing');
    expect(c.consumePendingCreateShift(), isTrue);
    expect(c.consumePendingCreateShift(), isFalse);
  });
}
