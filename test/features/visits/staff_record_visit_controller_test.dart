import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 13, 9);

VisitOut _visit({String status = 'scheduled'}) {
  return VisitOut(
    id: 'visit-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    contractorId: 'contractor-1',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 1)),
    status: status,
    source: 'manual',
    latitude: 0,
    longitude: 0,
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
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
    registerFallbackValue(
      AdminRecordVisitRequest(
        visitId: 'visit-1',
        clockInAt: _now,
        clockOutAt: _now.add(const Duration(hours: 1)),
        reason: 'fallback',
      ),
    );
  });

  setUp(() {
    Get.testMode = true;
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(false);
    when(
      () => session.hasPermission(AppPermissions.attendanceAdjust),
    ).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(
      () => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to')),
    ).thenAnswer((_) async => []);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
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

  test('canRecordVisit is true for scheduled visit with attendance.adjust', () {
    when(
      () => session.hasPermission(AppPermissions.attendanceAdjust),
    ).thenReturn(true);
    controller.selected.value = _visit(status: 'scheduled');
    expect(controller.canRecordVisit, isTrue);
  });

  test('canRecordVisit is false without attendance.adjust', () {
    when(
      () => session.hasPermission(AppPermissions.attendanceAdjust),
    ).thenReturn(false);
    when(() => session.hasPermission(any())).thenReturn(false);
    controller.selected.value = _visit(status: 'scheduled');
    expect(controller.canRecordVisit, isFalse);
  });

  test('canRecordVisit is false when visit is completed', () {
    when(
      () => session.hasPermission(AppPermissions.attendanceAdjust),
    ).thenReturn(true);
    controller.selected.value = _visit(status: 'completed');
    expect(controller.canRecordVisit, isFalse);
  });

  test('recordVisit posts then refreshes selected visit', () async {
    when(
      () => session.hasPermission(AppPermissions.attendanceAdjust),
    ).thenReturn(true);
    controller.selected.value = _visit(status: 'scheduled');
    when(() => visits.recordVisit(any())).thenAnswer(
      (_) async => const AdminRecordVisitOut(
        adjustmentId: 'adj-1',
        timeEntryId: 'te-1',
        visitId: 'visit-1',
        status: 'closed',
        visitStatus: 'completed',
      ),
    );
    when(
      () => visits.getVisit('visit-1'),
    ).thenAnswer((_) async => _visit(status: 'completed'));

    final ok = await controller.recordVisit(
      clockInAt: DateTime.utc(2026, 9, 1, 9),
      clockOutAt: DateTime.utc(2026, 9, 1, 11),
      reason: 'Paper timesheet',
    );

    expect(ok, isTrue);
    expect(controller.selected.value?.isCompleted, isTrue);
    verify(() => visits.recordVisit(any())).called(1);
  });

  test('recordVisit surfaces AppFailure on error', () async {
    when(
      () => session.hasPermission(AppPermissions.attendanceAdjust),
    ).thenReturn(true);
    controller.selected.value = _visit(status: 'scheduled');
    when(() => visits.recordVisit(any())).thenThrow(
      const AppFailure(
        code: 'visit_cancelled',
        message: 'Visit is cancelled',
        presentation: AppFailurePresentation.screen,
        statusCode: 409,
      ),
    );

    final ok = await controller.recordVisit(
      clockInAt: DateTime.utc(2026, 9, 1, 9),
      clockOutAt: DateTime.utc(2026, 9, 1, 11),
      reason: 'oops',
    );

    expect(ok, isFalse);
    expect(controller.errorMessage.value, 'Visit is cancelled');
  });
}
