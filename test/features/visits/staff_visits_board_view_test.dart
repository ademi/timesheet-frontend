import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/responsive/page_content.dart';
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

JobOut _job({
  String id = _jobId,
  String title = 'Morning support',
  String? clientId,
}) {
  return JobOut(
    id: id,
    tenantId: 'tenant-1',
    clientId: clientId,
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
    'client filter primary; support filter hidden with no client selected',
    (tester) async {
      final gate = Completer<List<JobOut>>();
      when(() => jobs.listJobs()).thenAnswer((_) => gate.future);

      // Deep-link job_id must not crash while jobs are still loading (D3).
      Get.routing.args = {'job_id': _jobId};
      putController();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffVisitsBoardView()),
      );
      await tester.pump();

      expect(find.text('All clients'), findsOneWidget);
      expect(find.text('Roster'), findsOneWidget);
      // No client selected → support sub-filter hidden.
      expect(find.text('All supports'), findsNothing);

      gate.complete([_job(clientId: 'c1')]);
      await tester.pump();
      await tester.pump();

      // Single support for client, and none selected → still hidden.
      expect(find.text('All supports'), findsNothing);
    },
  );

  testWidgets(
    'support sub-filter appears when selected client has two open supports',
    (tester) async {
      when(() => jobs.listJobs()).thenAnswer(
        (_) async => [
          _job(id: 'j1', title: 'Morning support', clientId: 'c1'),
          _job(id: 'j2', title: 'Evening support', clientId: 'c1'),
        ],
      );

      putController();

      await tester.pumpWidget(
        const GetMaterialApp(home: StaffVisitsBoardView()),
      );
      await tester.pump();
      await tester.pump();

      // Hidden until a client is picked.
      expect(find.text('All supports'), findsNothing);

      Get.find<StaffVisitsController>().setClientFilter('c1');
      await tester.pump();

      expect(find.text('All supports'), findsOneWidget);
    },
  );

  testWidgets('wide roster content is centered', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    putController();
    await tester.pumpWidget(
      const GetMaterialApp(home: StaffVisitsBoardView()),
    );
    await tester.pump();
    await tester.pump();

    final cap = find.descendant(
      of: find.byType(PageContent).first,
      matching: find.byType(ConstrainedBox),
    );
    final page = tester.getRect(cap.first);
    expect(page.width, closeTo(1200, 1));
    expect(page.center.dx, closeTo(800, 8));

    final clientField = find.byType(DropdownButtonFormField<String>).first;
    final clientCenter = tester.getCenter(clientField);
    expect(clientCenter.dx, greaterThan(page.left));
    expect(clientCenter.dx, lessThan(page.center.dx));
  });
}
