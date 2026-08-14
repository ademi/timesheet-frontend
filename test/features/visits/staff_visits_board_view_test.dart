import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/views/staff_visits_board_view.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeHorizonRequest extends Fake implements HorizonRequest {}

const _jobId = 'd65d130b-baca-4fe0-8f18-de65356b7a22';

final _now = DateTime.utc(2026, 8, 14, 9);

JobOut _job({String id = _jobId, String title = 'Morning support'}) {
  return JobOut(
    id: id,
    tenantId: 'tenant-1',
    kind: 'standing',
    status: 'open',
    title: title,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: _now,
    updatedAt: _now,
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
    when(() => session.tenantId).thenReturn(RxnString());
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
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(
      () => engagements.listTenantEngagements(),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  StaffVisitsController putController() {
    final controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: jobs,
      engagementsRepository: engagements,
      session: session,
    );
    Get.put(controller);
    return controller;
  }

  testWidgets(
    'does not assert when route job_id is set before jobs have loaded',
    (tester) async {
      final gate = Completer<List<JobOut>>();
      when(() => jobs.listJobs()).thenAnswer((_) => gate.future);

      Get.routing.args = {'job_id': _jobId};
      putController();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffVisitsBoardView()),
      );
      await tester.pump();

      expect(find.text('All jobs'), findsOneWidget);
      expect(find.text('All clients'), findsOneWidget);
      expect(find.text('Roster'), findsOneWidget);

      gate.complete([_job()]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Morning support'), findsOneWidget);
      expect(find.text('Unfilled'), findsOneWidget);
    },
  );

  testWidgets(
    'dedupes duplicate job ids so the filter dropdown can select one',
    (tester) async {
      when(() => jobs.listJobs()).thenAnswer(
        (_) async => [_job(), _job(title: 'Duplicate copy')],
      );

      Get.routing.args = {'job_id': _jobId};
      putController();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffVisitsBoardView()),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Morning support'), findsOneWidget);
      expect(find.text('Duplicate copy'), findsNothing);
    },
  );
}
