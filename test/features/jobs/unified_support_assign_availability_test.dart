import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
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
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        includeNested: any(named: 'includeNested'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  UnifiedSupportController build({
    UnifiedSupportMode mode = UnifiedSupportMode.oneSession,
  }) {
    return UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
      visitsRepository: visits,
      session: session,
      args: UnifiedSupportArgs.forClient(
        client,
        mode: mode,
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

  test('ensureAssignAvailabilityLoaded fetches lite visits', () async {
    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    verify(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        includeNested: false,
      ),
    ).called(1);
  });

  test('availabilityLabelForContractor returns Busy for overlapping visit',
      () async {
    final start = DateTime(2026, 8, 13, 9);
    final end = DateTime(2026, 8, 13, 12);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        includeNested: any(named: 'includeNested'),
      ),
    ).thenAnswer(
      (_) async => [
        VisitOut(
          id: 'v-busy',
          tenantId: 'tenant-1',
          jobId: 'job-other',
          contractorId: 'contractor-busy',
          scheduledStart: start,
          scheduledEnd: end,
          status: 'scheduled',
          source: 'manual',
          geofenceRadiusM: 100,
          geofenceMode: 'informational',
          paymentStatus: 'unpaid',
          createdAt: start,
          updatedAt: start,
        ),
      ],
    );

    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = start;
    controller.oneSessionEnd.value = end;
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

  test('clientConflicts includes unfilled shift overlapping window', () async {
    final start = DateTime(2026, 8, 13, 9);
    final end = DateTime(2026, 8, 13, 12);
    when(() => jobs.getOngoingSupport('client-1')).thenAnswer(
      (_) async => JobOut(
        id: 'standing-job',
        tenantId: 'tenant-1',
        kind: 'standing',
        status: 'open',
        title: 'Sam Lee support',
        geofenceRadiusM: 100,
        geofenceMode: 'informational',
        createdAt: start,
        updatedAt: start,
        clientId: 'client-1',
      ),
    );
    when(
      () => shifts.listShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
      ),
    ).thenAnswer(
      (_) async => [
        ShiftOut(
          id: 'hole-1',
          tenantId: 'tenant-1',
          jobId: 'standing-job',
          jobTitle: 'Sam Lee support',
          clientId: 'client-1',
          clientName: 'Sam Lee',
          scheduledStart: start,
          scheduledEnd: end,
          requiredSlots: 2,
          openSlots: 1,
          status: 'published',
          createdAt: start,
          updatedAt: start,
        ),
      ],
    );

    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = start;
    controller.oneSessionEnd.value = end;
    controller.step.value = UnifiedSupportController.scheduleStep;

    await controller.ensureClientConflictsLoaded();

    expect(controller.clientConflicts.map((c) => c.id), ['hole-1']);
    expect(controller.canGoNext(), isTrue);
  });

  test('availabilityLabelForContractor returns Outside hours for preferred mismatch',
      () async {
    when(
      () => visits.fetchRosterOverlay(from: any(named: 'from'), to: any(named: 'to')),
    ).thenAnswer(
      (_) async => RosterOverlayOut(
        contractors: [
          ContractorRosterOverlay(
            contractorId: 'contractor-1',
            displayName: 'Alex',
            availability: [
              AvailabilityRuleOut(
                dayOfWeek: DateTime(2026, 8, 13).weekday - DateTime.monday,
                startTime: '09:00:00',
                endTime: '12:00:00',
              ),
            ],
          ),
        ],
      ),
    );

    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 18);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 20);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(
      controller.availabilityLabelForContractor('contractor-1'),
      'Outside hours',
    );
    expect(controller.assignOverlayWarning.value, isNull);
  });

  test('overlay failure sets leave warning; shift failure does not', () async {
    when(
      () => visits.fetchRosterOverlay(from: any(named: 'from'), to: any(named: 'to')),
    ).thenThrow(Exception('overlay down'));
    when(
      () => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to')),
    ).thenThrow(Exception('shifts down'));

    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(
      controller.assignOverlayWarning.value,
      'Could not load leave and preferred hours',
    );
  });

  test('shift-only failure does not show leave unavailable banner', () async {
    when(
      () => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to')),
    ).thenThrow(Exception('shifts down'));

    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(controller.assignOverlayWarning.value, isNull);
    expect(controller.assignAvailabilityLoaded, isTrue);
  });

  test(
      'ongoing display label appends on first date; base status stays Busy',
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

    final controller = build(mode: UnifiedSupportMode.ongoing);
    await controller.load();
    controller.startDate.value = DateTime(2026, 8, 13);
    controller.weekdays
      ..clear()
      ..add(DateTime.thursday);
    controller.startTime.value = const TimeOfDay(hour: 9, minute: 0);
    controller.endTime.value = const TimeOfDay(hour: 12, minute: 0);
    controller.selectContractorForSlot(0, 'contractor-busy');
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(
      controller.availabilityStatusForContractor('contractor-busy'),
      'Busy',
    );
    expect(
      controller.availabilityDisplayLabelForContractor('contractor-busy'),
      'Busy on first date',
    );
    expect(
      controller.busyAssignedWorkers.map((e) => e.contractorId),
      contains('contractor-busy'),
    );
  });

  test('one-session display label has no suffix', () async {
    final controller = build();
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await controller.ensureAssignAvailabilityLoaded();

    expect(controller.availabilityDisplayLabelForContractor('x'), 'Free');
  });
}
