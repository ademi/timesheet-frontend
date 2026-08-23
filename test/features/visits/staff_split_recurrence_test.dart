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

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

class _FakeSplitRecurrenceRequest extends Fake
    implements SplitRecurrenceRequest {}

final _now = DateTime.utc(2026, 8, 17, 9);

ShiftOut _shift({String? recurrenceRuleId = 'rule-1'}) {
  return ShiftOut(
    id: 'shift-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Morning support',
    clientName: 'Jane Client',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 3)),
    requiredSlots: 1,
    openSlots: 1,
    status: 'published',
    recurrenceRuleId: recurrenceRuleId,
    assignments: const [],
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
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
    registerFallbackValue(_FakeSplitRecurrenceRequest());
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
    when(() => jobs.ensureHorizon(any())).thenAnswer((_) async => HorizonOut.empty);
    when(
      () => engagements.listTenantEngagements(),
    ).thenAnswer((_) async => []);
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

  test('editThisAndFuture posts split-from and refreshes', () async {
    final out = SplitRecurrenceOut(
      oldRule: RecurrenceRuleOut(
        id: 'rule-1',
        tenantId: 'tenant-1',
        jobId: 'job-1',
        requiredSlots: 1,
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
        dtstart: _now,
        timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
        isActive: true,
        createdAt: _now,
        updatedAt: _now,
        until: _now.subtract(const Duration(days: 1)),
      ),
      newRule: RecurrenceRuleOut(
        id: 'rule-2',
        tenantId: 'tenant-1',
        jobId: 'job-1',
        requiredSlots: 1,
        rrule: 'FREQ=WEEKLY;BYDAY=MO',
        dtstart: _now,
        timeWindows: const [TimeWindow(startTime: '10:00', endTime: '13:00')],
        isActive: true,
        createdAt: _now,
        updatedAt: _now,
      ),
      horizon: HorizonOut.empty,
    );
    when(
      () => jobs.splitRecurrenceFrom(
        jobId: any(named: 'jobId'),
        ruleId: any(named: 'ruleId'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => out);

    await controller.editThisAndFuture(
      tile: _shift(),
      windows: const [TimeWindow(startTime: '10:00', endTime: '13:00')],
    );

    final captured =
        verify(
              () => jobs.splitRecurrenceFrom(
                jobId: 'job-1',
                ruleId: 'rule-1',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as SplitRecurrenceRequest;
    expect(captured.timeWindows.single.startTime, '10:00');
    expect(captured.requiredSlots, 1);
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
  });

  test('editThisAndFuture without ruleId sets error', () async {
    await controller.editThisAndFuture(
      tile: _shift(recurrenceRuleId: null),
      windows: const [TimeWindow(startTime: '10:00', endTime: '13:00')],
    );
    expect(controller.errorMessage.value, contains('not part of a pattern'));
    verifyNever(
      () => jobs.splitRecurrenceFrom(
        jobId: any(named: 'jobId'),
        ruleId: any(named: 'ruleId'),
        body: any(named: 'body'),
      ),
    );
  });

  test('editThisAndFuture surfaces split_blocked_by_active_visit', () async {
    when(
      () => jobs.splitRecurrenceFrom(
        jobId: any(named: 'jobId'),
        ruleId: any(named: 'ruleId'),
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'split_blocked_by_active_visit',
        message:
            'Can’t change this pattern — a future visit is already in progress or completed.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    await controller.editThisAndFuture(
      tile: _shift(),
      windows: const [TimeWindow(startTime: '10:00', endTime: '13:00')],
    );

    expect(controller.errorMessage.value, contains('already in progress'));
  });
}
