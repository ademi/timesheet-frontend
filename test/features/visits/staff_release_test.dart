import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
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

final _now = DateTime.utc(2026, 8, 14, 9);

ShiftOut _shift({
  String id = 'shift-1',
  int openSlots = 1,
  List<ShiftAssignmentOut> assignments = const [],
}) {
  return ShiftOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Morning support',
    clientName: 'Jane Client',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 3)),
    requiredSlots: 1,
    openSlots: openSlots,
    status: 'published',
    assignments: assignments,
    createdAt: _now,
    updatedAt: _now,
  );
}

ShiftAssignmentOut _assignment({
  String contractorId = 'contractor-1',
  String name = 'Jane',
  String visitStatus = 'scheduled',
}) {
  return ShiftAssignmentOut(
    id: 'asn-1',
    contractorId: contractorId,
    contractorName: name,
    visitId: 'visit-1',
    source: 'staff_assign',
    status: 'active',
    visitStatus: visitStatus,
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

  test('releaseAssignment calls unassignShift and sets success snack', () async {
    final assigned = _shift(
      openSlots: 0,
      assignments: [_assignment()],
    );
    final after = _shift(openSlots: 1);
    controller.selectedShift.value = assigned;
    when(
      () => shifts.unassignShift('shift-1', 'contractor-1'),
    ).thenAnswer((_) async => after);

    await controller.releaseAssignment(
      shiftId: 'shift-1',
      contractorId: 'contractor-1',
      workerName: 'Jane',
      skipConfirm: true,
    );

    verify(() => shifts.unassignShift('shift-1', 'contractor-1')).called(1);
    expect(
      controller.lastReleaseSnack,
      'Hole opened — eligible workers notified.',
    );
    expect(controller.selectedShift.value?.openSlots, 1);
    expect(controller.errorMessage.value, isNull);
  });

  test(
    'releaseAssignment maps invalid_visit_status to checked-in copy',
    () async {
      when(() => shifts.unassignShift('shift-1', 'contractor-1')).thenThrow(
        const AppFailure(
          code: 'invalid_visit_status',
          message: 'Visit status changed. Refresh and try again.',
          presentation: AppFailurePresentation.inline,
          statusCode: 409,
        ),
      );

      await controller.releaseAssignment(
        shiftId: 'shift-1',
        contractorId: 'contractor-1',
        workerName: 'Jane',
        skipConfirm: true,
      );

      expect(
        controller.lastReleaseSnack,
        'Already checked in — cancel the shift first.',
      );
      expect(
        controller.errorMessage.value,
        'Already checked in — cancel the shift first.',
      );
    },
  );

  test('releaseAssignment no-ops without shifts.manage', () async {
    when(
      () => session.hasPermission(AppPermissions.shiftsManage),
    ).thenReturn(false);
    when(() => session.hasPermission(any())).thenReturn(false);

    await controller.releaseAssignment(
      shiftId: 'shift-1',
      contractorId: 'contractor-1',
      skipConfirm: true,
    );

    verifyNever(() => shifts.unassignShift(any(), any()));
  });
}
