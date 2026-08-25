import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/roster/support_filter.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

class _FakeShiftCreateRequest extends Fake implements ShiftCreateRequest {}

final _now = DateTime.utc(2026, 8, 14, 9);

JobOut _job({
  required String id,
  String? clientId = 'c1',
  String kind = 'standing',
  String status = 'open',
}) {
  return JobOut(
    id: id,
    tenantId: 'tenant-1',
    clientId: clientId,
    kind: kind,
    status: status,
    title: '$id title',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  group('support_filter helpers', () {
    test('jobsForClientFilter empty when one support', () {
      final jobs = [_job(id: 'j1')];
      expect(jobsForClientFilter(jobs, clientId: 'c1').length, 1);
      expect(shouldShowSupportFilter(jobs, clientId: 'c1'), isFalse);
    });

    test('shouldShowSupportFilter true when two open jobs same client', () {
      final twoJobsSameClient = [_job(id: 'j1'), _job(id: 'j2')];
      expect(shouldShowSupportFilter(twoJobsSameClient, clientId: 'c1'), isTrue);
    });

    test('jobsForClientFilter excludes other clients and closed supports', () {
      final jobs = [
        _job(id: 'j1'),
        _job(id: 'j2', clientId: 'c2'),
        _job(id: 'j3', status: 'closed'),
      ];
      final result = jobsForClientFilter(jobs, clientId: 'c1');
      expect(result.map((j) => j.id), ['j1']);
    });

    test('shouldShowSupportFilter false when clientId null or empty', () {
      final jobs = [_job(id: 'j1'), _job(id: 'j2')];
      expect(shouldShowSupportFilter(jobs, clientId: null), isFalse);
      expect(shouldShowSupportFilter(jobs, clientId: ''), isFalse);
    });
  });

  group('StaffVisitsController client-first booking', () {
    late _MockVisitsRepository visits;
    late _MockShiftsRepository shifts;
    late _MockJobsRepository jobs;
    late _MockEngagementsRepository engagements;
  late _MockClientsRepository clients;
    late _MockSessionService session;
    late StaffVisitsController controller;

    setUpAll(() {
      registerFallbackValue(DateTime.utc(2026, 1, 1));
      registerFallbackValue(_FakeHorizonRequest());
      registerFallbackValue(_FakeShiftCreateRequest());
    });

    setUp(() {
      Get.reset();
      Get.testMode = true;
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
        ),
      ).thenAnswer((_) async => <ShiftOut>[]);
      when(
        () => visits.fetchRosterOverlay(
          from: any(named: 'from'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => const RosterOverlayOut(contractors: []));
      when(() => jobs.listJobs()).thenAnswer((_) async => []);
      when(() => jobs.ensureHorizon(any()))
          .thenAnswer((_) async => HorizonOut.empty);
      when(() => engagements.listTenantEngagements())
          .thenAnswer((_) async => []);
      controller = StaffVisitsController(
        repository: visits,
        shiftsRepository: shifts,
        jobsRepository: jobs,
        engagementsRepository: engagements,
        clientsRepository: clients,
        session: session,
      );
    });

    tearDown(Get.reset);

    test('bookOneForClient ensures support then creates shift', () async {
      final support = _job(id: 'support-1');
      final created = ShiftOut(
        id: 'shift-1',
        tenantId: 'tenant-1',
        jobId: support.id,
        jobTitle: support.title,
        scheduledStart: _now,
        scheduledEnd: _now.add(const Duration(hours: 3)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: _now,
        updatedAt: _now,
      );
      when(() => jobs.ensureOngoingSupport('c1'))
          .thenAnswer((_) async => support);
      when(() => shifts.createShift(any())).thenAnswer((_) async => created);

      final ok = await controller.bookOneForClient(
        clientId: 'c1',
        start: DateTime(2026, 8, 20, 9),
        end: DateTime(2026, 8, 20, 12),
      );

      expect(ok, isTrue);
      verify(() => jobs.ensureOngoingSupport('c1')).called(1);
      final req = verify(() => shifts.createShift(captureAny())).captured.single
          as ShiftCreateRequest;
      expect(req.jobId, support.id);
      expect(req.status, 'published');
      expect(controller.errorMessage.value, isNull);
    });

    test('bookOneForClient surfaces site_or_branch_required (D10)', () async {
      when(() => jobs.ensureOngoingSupport('c1')).thenThrow(
        const AppFailure(
          code: 'site_or_branch_required',
          message: 'Add a site or branch for this client before booking support.',
          presentation: AppFailurePresentation.inline,
        ),
      );

      final ok = await controller.bookOneForClient(
        clientId: 'c1',
        start: DateTime(2026, 8, 20, 9),
        end: DateTime(2026, 8, 20, 12),
      );

      expect(ok, isFalse);
      expect(controller.errorMessage.value, contains('site or branch'));
      verifyNever(() => shifts.createShift(any()));
    });

    test('setClientFilter always clears prior support filter', () async {
      controller.jobs.assignAll([
        _job(id: 'j1'),
        _job(id: 'j2'),
        _job(id: 'j3', clientId: 'c2'),
        _job(id: 'j4', clientId: 'c2'),
      ]);
      controller.clientIdFilter.value = 'c1';
      controller.jobIdFilter.value = 'j1';

      controller.setClientFilter('c2');

      expect(controller.jobIdFilter.value, '');
      expect(controller.clientIdFilter.value, 'c2');
      expect(controller.showSupportFilter, isTrue);
    });

    test('showSupportFilter true when client has two open supports', () {
      controller.jobs.assignAll([_job(id: 'j1'), _job(id: 'j2')]);
      controller.clientIdFilter.value = 'c1';

      expect(controller.showSupportFilter, isTrue);
      expect(controller.supportsForSelectedClient.map((j) => j.id),
          containsAll(['j1', 'j2']));
    });
  });
}
