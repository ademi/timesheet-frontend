import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

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

void _stubListShifts(_MockShiftsRepository shifts) {
  when(
    () => shifts.listShifts(
      from: any(named: 'from'),
      to: any(named: 'to'),
      jobId: any(named: 'jobId'),
    ),
  ).thenAnswer((_) async => <ShiftOut>[]);
}

HorizonOut _horizon({
  List<String> createdShiftIds = const [],
  List<GenerateVisitsConflict> skipped = const [],
}) {
  return HorizonOut(
    createdShiftIds: createdShiftIds,
    createdVisitIds: const [],
    skipped: skipped,
    rulesProcessed: skipped.isEmpty && createdShiftIds.isEmpty ? 0 : 1,
    truncated: false,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockSessionService session;
  late StaffVisitsController controller;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
    registerFallbackValue(_FakeHorizonRequest());
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    _stubListShifts(shifts);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(
      () => engagements.listTenantEngagements(),
    ).thenAnswer((_) async => []);
    controller = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      session: session,
    );
  });

  tearDown(Get.reset);

  Future<void> _flushHorizon() => Future<void>.delayed(Duration.zero);

  test(
    'ensureBoardLoaded posts horizon when jobs.manage and does not block empty list',
    () async {
      final gate = Completer<HorizonOut>();
      when(() => jobs.ensureHorizon(any())).thenAnswer((_) => gate.future);

      await controller.ensureBoardLoaded();

      expect(controller.shifts, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.isFillingHorizon.value, isTrue);
      expect(controller.errorMessage.value, isNull);
      verify(
        () => shifts.listShifts(
          from: any(named: 'from'),
          to: any(named: 'to'),
          jobId: any(named: 'jobId'),
        ),
      ).called(1);
      verify(() => jobs.ensureHorizon(any())).called(1);

      gate.complete(HorizonOut.empty);
      await _flushHorizon();
      expect(controller.isFillingHorizon.value, isFalse);
    },
  );

  test('ensureBoardLoaded skips horizon without jobs.manage', () async {
    when(() => session.hasPermission(any())).thenAnswer((invocation) {
      final perm = invocation.positionalArguments.first as String;
      return perm != AppPermissions.jobsManage;
    });

    await controller.ensureBoardLoaded();
    await _flushHorizon();

    verifyNever(() => jobs.ensureHorizon(any()));
    expect(controller.isFillingHorizon.value, isFalse);
  });

  test(
    'second ensureBoardLoaded while horizon in flight does not double POST',
    () async {
      final gate = Completer<HorizonOut>();
      when(() => jobs.ensureHorizon(any())).thenAnswer((_) => gate.future);

      await controller.ensureBoardLoaded();
      await controller.ensureBoardLoaded();

      verify(() => jobs.ensureHorizon(any())).called(1);
      gate.complete(
        const HorizonOut(
          createdShiftIds: [],
          createdVisitIds: [],
          skipped: [],
          rulesProcessed: 0,
          truncated: false,
        ),
      );
      await _flushHorizon();
    },
  );

  test('skipHorizonOnce from composer land does not POST', () async {
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);
    controller.skipHorizonOnce = true;

    await controller.ensureBoardLoaded();
    await _flushHorizon();

    verifyNever(() => jobs.ensureHorizon(any()));
    expect(controller.skipHorizonOnce, isFalse);
  });

  test('cooldown skips a second POST within 60s', () async {
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);

    await controller.ensureBoardLoaded();
    await _flushHorizon();
    await controller.ensureBoardLoaded();
    await _flushHorizon();

    verify(() => jobs.ensureHorizon(any())).called(1);
  });

  test('snackbar only when createdShiftIds is non-empty', () async {
    when(() => jobs.ensureHorizon(any())).thenAnswer(
      (_) async => _horizon(
        skipped: [
          GenerateVisitsConflict(
            scheduledStart: DateTime.utc(2026, 8, 10),
            detail: 'visit_overlap',
          ),
        ],
      ),
    );

    await controller.ensureBoardLoaded();
    await _flushHorizon();

    expect(controller.horizonSnackCount, 0);
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
  });

  test('created shifts reload list and notify once', () async {
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => _horizon(createdShiftIds: const ['s1', 's2']));

    await controller.ensureBoardLoaded();
    await _flushHorizon();

    expect(controller.horizonSnackCount, 1);
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(2);
  });

  test('horizon 5xx does not set errorMessage after list painted', () async {
    when(() => jobs.ensureHorizon(any())).thenThrow(
      const AppFailure(
        code: 'server_error',
        message: 'horizon exploded',
        presentation: AppFailurePresentation.screen,
      ),
    );

    await controller.ensureBoardLoaded();
    await _flushHorizon();

    expect(controller.errorMessage.value, isNull);
    expect(controller.shifts, isEmpty);
    expect(controller.isFillingHorizon.value, isFalse);
  });

  test('horizon 429 does not set errorMessage', () async {
    when(() => jobs.ensureHorizon(any())).thenThrow(
      const AppFailure(
        code: 'rate_limited',
        message: 'Too many requests. Try again shortly.',
        presentation: AppFailurePresentation.toast,
      ),
    );

    await controller.ensureBoardLoaded();
    await _flushHorizon();

    expect(controller.errorMessage.value, isNull);
  });

  test(
    'horizon window is fourteen days from start of today not visible week',
    () async {
      when(
        () => jobs.ensureHorizon(any()),
      ).thenAnswer((_) async => HorizonOut.empty);
      controller.rangeStart.value = DateTime(2020, 1, 15);

      await controller.ensureBoardLoaded();
      await _flushHorizon();

      final req =
          verify(() => jobs.ensureHorizon(captureAny())).captured.single
              as HorizonRequest;
      expect(req.to.difference(req.from), const Duration(days: 14));
      final now = DateTime.now();
      expect(req.from, DateTime(now.year, now.month, now.day).toUtc());
      expect(req.ruleIds, isNull);
    },
  );

  test('applyRouteArgs sets skipHorizonOnce and pendingClientIdFilter', () {
    Get.routing.args = {
      'skipHorizonOnce': true,
      'job_id': 'job-1',
      'client_id': 'client-1',
    };
    controller.applyRouteArgs();
    expect(controller.skipHorizonOnce, isTrue);
    expect(controller.pendingClientIdFilter, 'client-1');
    expect(controller.jobIdFilter.value, 'job-1');
  });

  test('shiftRange reloads list then fills horizon', () async {
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);

    controller.shiftRange(7);
    await _flushHorizon();
    await _flushHorizon();

    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
    verify(() => jobs.ensureHorizon(any())).called(1);
  });

  test('setJobFilter does not POST horizon', () async {
    controller.setJobFilter('job-1');
    await _flushHorizon();

    verifyNever(() => jobs.ensureHorizon(any()));
    verify(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).called(1);
  });
}
