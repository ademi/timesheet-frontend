import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockShiftsRepository shifts;
  late _MockVisitsRepository visits;
  late _MockSessionService session;

  final now = DateTime(2026, 8, 13, 9);
  final client = ClientOut(
    id: 'client-1',
    tenantId: 'tenant-1',
    fullName: 'Sam Lee',
    status: 'active',
    metadata: const {},
    createdAt: now,
    updatedAt: now,
  );

  setUpAll(() {
    registerFallbackValue(now);
  });

  setUp(() {
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    shifts = _MockShiftsRepository();
    visits = _MockVisitsRepository();
    session = _MockSessionService();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => clients.listClients()).thenAnswer((_) async => [client]);
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(),
    );
    when(() => jobs.listFormTemplates(tenantLevel: true))
        .thenAnswer((_) async => []);
    when(
      () => visits.fetchRosterOverlay(from: any(named: 'from'), to: any(named: 'to')),
    ).thenAnswer((_) async => const RosterOverlayOut(contractors: []));
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  UnifiedSupportController build() {
    return UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
      visitsRepository: visits,
      session: session,
      args: UnifiedSupportArgs.forClient(
        client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
  }

  test('ensureAssignAvailabilityLoaded fetches overlay and shifts for window',
      () async {
    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    verify(
      () => visits.fetchRosterOverlay(from: any(named: 'from'), to: any(named: 'to')),
    ).called(1);
    verify(
      () => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to')),
    ).called(1);
  });

  test('availabilityLabelForContractor returns Free when overlay empty', () async {
    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(
      controller.availabilityLabelForContractor('contractor-1'),
      'Free',
    );
  });

  test('availabilityLabelForContractor returns Busy for overlapping shift',
      () async {
    final shiftStart = DateTime(2026, 8, 13, 9);
    final shiftEnd = DateTime(2026, 8, 13, 12);
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => [
        ShiftOut(
          id: 'shift-busy',
          tenantId: 'tenant-1',
          jobId: 'job-2',
          jobTitle: 'Other',
          clientId: 'client-2',
          clientName: 'Other',
          scheduledStart: shiftStart,
          scheduledEnd: shiftEnd,
          requiredSlots: 1,
          openSlots: 0,
          status: 'published',
          assignments: [
            ShiftAssignmentOut(
              id: 'a-1',
              contractorId: 'contractor-busy',
              contractorName: 'Busy Worker',
              visitId: 'visit-1',
              source: 'staff_assign',
              status: 'active',
            ),
          ],
          createdAt: shiftStart,
          updatedAt: shiftStart,
        ),
      ],
    );

    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = shiftStart;
    controller.oneSessionEnd.value = shiftEnd;
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(
      controller.availabilityLabelForContractor('contractor-busy'),
      'Busy',
    );
    expect(
      controller.availabilityLabelForContractor('contractor-free'),
      'Free',
    );
  });

  test('nextStep loads assign availability when entering assign step', () async {
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => []);
    final controller = build();
    await controller.load();
    controller.step.value = UnifiedSupportController.detailsStep;

    controller.nextStep();

    await Future<void>.delayed(Duration.zero);
    verify(
      () => visits.fetchRosterOverlay(from: any(named: 'from'), to: any(named: 'to')),
    ).called(1);
  });

  test('concurrent ensureAssignAvailabilityLoaded coalesces to one fetch', () async {
    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await Future.wait([
      controller.ensureAssignAvailabilityLoaded(),
      controller.ensureAssignAvailabilityLoaded(),
    ]);

    verify(
      () => visits.fetchRosterOverlay(from: any(named: 'from'), to: any(named: 'to')),
    ).called(1);
    verify(
      () => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to')),
    ).called(1);
  });

  test('concurrent ensureEngagementsLoaded coalesces to one fetch', () async {
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => []);
    final controller = build();

    await Future.wait([
      controller.ensureEngagementsLoaded(),
      controller.ensureEngagementsLoaded(),
    ]);

    verify(() => engagements.listTenantEngagements()).called(1);
  });
}
