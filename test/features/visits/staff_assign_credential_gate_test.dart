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

ShiftOut _shift({String id = 'shift-1'}) {
  return ShiftOut(
    id: id,
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Morning support',
    clientName: 'Jane Client',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 3)),
    requiredSlots: 1,
    openSlots: 1,
    status: 'published',
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
    when(
      () => jobs.ensureHorizon(any()),
    ).thenAnswer((_) async => HorizonOut.empty);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
    controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: jobs,
      engagementsRepository: engagements,
      clientsRepository: clients,
      session: session,
    );
    controller.selectedShift.value = _shift();
  });

  tearDown(Get.reset);

  test('assign blocked surfaces credential gate reasons panel data', () async {
    when(
      () => shifts.assignShift(
        shiftId: any(named: 'shiftId'),
        contractorId: any(named: 'contractorId'),
        taskTemplate: any(named: 'taskTemplate'),
        overrideReason: any(named: 'overrideReason'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'credential_gate_blocked',
        message: 'Screening blocked',
        presentation: AppFailurePresentation.inline,
        eligibilityReasons: ['wwcc: expired'],
      ),
    );

    await controller.assignSelectedShift('contractor-1', skipConfirm: true);

    expect(controller.errorMessage.value, 'Screening blocked');
    expect(controller.credentialGateReasons, ['wwcc: expired']);
  });

  test('assign with override_reason succeeds', () async {
    when(
      () => shifts.assignShift(
        shiftId: any(named: 'shiftId'),
        contractorId: any(named: 'contractorId'),
        taskTemplate: any(named: 'taskTemplate'),
        overrideReason: any(named: 'overrideReason'),
      ),
    ).thenAnswer((_) async => _shift());

    await controller.assignSelectedShift(
      'contractor-1',
      skipConfirm: true,
      overrideReason: 'Director approved temporary cover',
    );

    expect(controller.errorMessage.value, isNull);
    expect(controller.credentialGateReasons, isEmpty);
    verify(
      () => shifts.assignShift(
        shiftId: 'shift-1',
        contractorId: 'contractor-1',
        taskTemplate: any(named: 'taskTemplate'),
        overrideReason: 'Director approved temporary cover',
      ),
    ).called(1);
  });
}
