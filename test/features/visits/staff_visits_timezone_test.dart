import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/payroll/data/models/payroll_models.dart';
import 'package:rostiq/features/payroll/data/repositories/payroll_repository.dart';
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

class _MockPayrollRepository extends Mock implements PayrollRepository {}

StaffVisitsController _controller({
  required _MockVisitsRepository visits,
  required _MockShiftsRepository shifts,
  required _MockJobsRepository jobs,
  required _MockEngagementsRepository engagements,
  required _MockClientsRepository clients,
  required _MockSessionService session,
  _MockPayrollRepository? payroll,
}) {
  return StaffVisitsController(
    repository: visits,
    shiftsRepository: shifts,
    jobsRepository: jobs,
    engagementsRepository: engagements,
    clientsRepository: clients,
    session: session,
    payroll: payroll,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late _MockPayrollRepository payroll;
  late StaffVisitsController controller;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    tenantUtcOffsetOverride = null;
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    payroll = _MockPayrollRepository();
    when(() => session.tenantId).thenReturn(RxnString('tenant-1'));
    when(() => session.tenantTimezone).thenReturn(RxnString());
    controller = _controller(
      visits: visits,
      shifts: shifts,
      jobs: jobs,
      engagements: engagements,
      clients: clients,
      session: session,
      payroll: payroll,
    );
  });

  tearDown(() {
    tenantUtcOffsetOverride = null;
    Get.reset();
  });

  test('week rangeStart stays on tenant civil Monday when timezone set', () {
    tenantUtcOffsetOverride = (tz, _) {
      if (tz == 'Australia/Sydney') return const Duration(hours: 10);
      return Duration.zero;
    };
    controller.tenantTimezone.value = 'Australia/Sydney';
    // Sun 16:00Z = Mon 02:00 AEST
    controller.alignRangeToTenantWeek(DateTime.utc(2026, 8, 9, 16));
    expect(controller.rangeStart.value.weekday, DateTime.monday);
    expect(controller.rangeStart.value.day, 10);
  });

  test('alignRangeToTenantWeek prefers session tenantTimezone', () {
    tenantUtcOffsetOverride = (tz, _) {
      if (tz == 'Australia/Sydney') return const Duration(hours: 10);
      return Duration.zero;
    };
    when(() => session.tenantTimezone).thenReturn(RxnString('Australia/Sydney'));
    // Sun 16:00Z = Mon 02:00 AEST — session TZ only (cached obs empty).
    controller.alignRangeToTenantWeek(DateTime.utc(2026, 8, 9, 16));
    expect(controller.rangeStart.value.weekday, DateTime.monday);
    expect(controller.rangeStart.value.day, 10);
  });

  test('loadTenantTimezone fetches once from payroll repository', () async {
    when(() => payroll.getTenant('tenant-1')).thenAnswer(
      (_) async => TenantSettingsOut(
        id: 'tenant-1',
        name: 'Demo',
        timezone: 'Australia/Sydney',
      ),
    );
    await controller.loadTenantTimezone();
    await controller.loadTenantTimezone();
    verify(() => payroll.getTenant('tenant-1')).called(1);
    expect(controller.tenantTimezone.value, 'Australia/Sydney');
  });

  test('loadTenantTimezone prefers session over payroll', () async {
    when(() => session.tenantTimezone).thenReturn(RxnString('Australia/Sydney'));
    when(() => payroll.getTenant('tenant-1')).thenAnswer(
      (_) async => TenantSettingsOut(
        id: 'tenant-1',
        name: 'Demo',
        timezone: 'Pacific/Auckland',
      ),
    );
    await controller.loadTenantTimezone();
    expect(controller.tenantTimezone.value, 'Australia/Sydney');
    verifyNever(() => payroll.getTenant(any()));
  });

  test('staff roster availabilityLabelForAssign passes tenant timezone', () {
    tenantUtcOffsetOverride = (tz, _) {
      if (tz == 'Australia/Sydney') return const Duration(hours: 10);
      return Duration.zero;
    };
    when(() => session.tenantTimezone).thenReturn(RxnString('Australia/Sydney'));

    final day = DateTime(2026, 8, 13);
    final leaveStartUtc = tenantCivilDateStartUtc(day, 'Australia/Sydney');
    controller.overlay.value = RosterOverlayOut(
      contractors: [
        ContractorRosterOverlay(
          contractorId: 'jane',
          displayName: 'Jane',
          leave: [
            LeaveIntervalOut(
              startDate: leaveStartUtc,
              endDate: leaveStartUtc,
              leaveType: 'annual',
            ),
          ],
          availability: const [],
        ),
      ],
    );
    final shift = ShiftOut(
      id: 's1',
      tenantId: 'tenant-1',
      jobId: 'j1',
      jobTitle: 'Support',
      clientId: 'c1',
      clientName: 'Sam',
      scheduledStart: DateTime(2026, 8, 13, 9),
      scheduledEnd: DateTime(2026, 8, 13, 12),
      requiredSlots: 1,
      openSlots: 1,
      status: 'published',
      assignments: const [],
      createdAt: day,
      updatedAt: day,
    );
    controller.selectedShift.value = shift;

    expect(
      controller.availabilityLabelForAssign(
        contractorId: 'jane',
        shift: shift,
      ),
      'Leave',
    );
  });
}
