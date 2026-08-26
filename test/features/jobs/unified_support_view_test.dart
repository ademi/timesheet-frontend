import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/recurrence_rrule_builder.dart';
import 'package:rostiq/features/jobs/utils/schedule_hours_warn.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/jobs/views/unified_support_view.dart';
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
  late UnifiedSupportController controller;
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockShiftsRepository shifts;
  late _MockVisitsRepository visits;
  late _MockSessionService session;

  final now = DateTime.utc(2026, 8, 13, 9);
  final client = ClientOut(
    id: 'client-1',
    tenantId: 'tenant-1',
    fullName: 'Sam Lee',
    status: 'active',
    metadata: const {},
    createdAt: now,
    updatedAt: now,
  );
  final site = ClientSiteOut(
    id: 'site-1',
    tenantId: 'tenant-1',
    clientId: 'client-1',
    name: 'Home',
    geofenceRadiusM: 100,
    isPrimary: true,
    createdAt: now,
    updatedAt: now,
  );

  setUpAll(() {
    registerFallbackValue(now);
  });

  setUp(() {
    Get.reset();
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
    when(() => clients.getClient(any())).thenAnswer((_) async => client);
    when(() => clients.listSites(any())).thenAnswer((_) async => [site]);
    when(() => clients.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(
        clientType: ClientTypeOut(
          id: 'type-1',
          code: 'patient',
          name: 'Patient',
          isActive: true,
          sortOrder: 0,
        ),
      ),
    );
    when(() => jobs.listFormTemplates(tenantLevel: true))
        .thenAnswer((_) async => []);
    when(() => engagements.listTenantEngagements())
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

    controller = UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
      visitsRepository: visits,
      session: session,
      args: UnifiedSupportArgs.forClient(
        client,
        mode: UnifiedSupportMode.ongoing,
      ),
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('shows client name at top when client selected', (
    tester,
  ) async {
    await controller.load();
    controller.step.value = 2;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sam Lee'), findsOneWidget);
    expect(find.text('Workers'), findsOneWidget);
    expect(find.text('Worker (optional)'), findsNothing);
  });

  testWidgets('shows amber warn on schedule step for atypical hours', (
    tester,
  ) async {
    await controller.load();
    controller.step.value = 2;
    controller.frequency.value = RecurrenceFrequency.daily;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text(kAtypicalScheduleHoursMessage), findsOneWidget);
  });

  testWidgets('schedule step rebuilds when start time and weekdays change', (
    tester,
  ) async {
    await controller.load();
    controller.step.value = 2;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);

    controller.startTime.value = const TimeOfDay(hour: 14, minute: 30);
    await tester.pump();

    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('09:00'), findsNothing);

    controller.endDate.value = DateTime(2027, 3, 15);
    await tester.pump();

    expect(
      find.text(MaterialLocalizations.of(
        tester.element(find.byType(UnifiedSupportView)),
      ).formatMediumDate(DateTime(2027, 3, 15))),
      findsOneWidget,
    );

    expect(find.widgetWithText(FilterChip, 'MO'), findsOneWidget);
    final mondayChip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'MO'),
    );
    expect(mondayChip.selected, isTrue);

    controller.toggleWeekday(DateTime.monday);
    controller.toggleWeekday(DateTime.wednesday);
    await tester.pump();

    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'MO')).selected,
      isFalse,
    );
    expect(
      tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'WE')).selected,
      isTrue,
    );
  });

  testWidgets('workers step shows one dropdown per required slot', (
    tester,
  ) async {
    await controller.load();
    controller.requiredSlots.value = 2;
    controller.syncAssignSlots(controller.requiredSlots.value);
    controller.engagements.assignAll([
      EngagementOut(
        id: 'eng-1',
        tenantId: 'tenant-1',
        contractorId: 'contractor-1',
        contractorName: 'Alex Worker',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
      EngagementOut(
        id: 'eng-2',
        tenantId: 'tenant-1',
        contractorId: 'contractor-2',
        contractorName: 'Blair Worker',
        status: 'active',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    controller.step.value = UnifiedSupportController.assignStep;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Worker 1 (optional)'), findsOneWidget);
    expect(find.text('Worker 2 (optional)'), findsOneWidget);
    expect(find.text('Unfilled'), findsNWidgets(2));
    expect(find.text('Worker assignment will be available in the next update.'),
        findsNothing);
  });

  testWidgets('ongoing assign dropdown shows Free on first date', (
    tester,
  ) async {
    final engagement = EngagementOut(
      id: 'eng-1',
      tenantId: 'tenant-1',
      contractorId: 'contractor-1',
      contractorName: 'Alex Worker',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => [engagement]);
    await controller.load();
    controller.startDate.value = DateTime(2026, 8, 13);
    controller.weekdays
      ..clear()
      ..add(DateTime.thursday);
    controller.step.value = UnifiedSupportController.assignStep;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('assign-slot-0')));
    await tester.tap(find.byKey(const ValueKey('assign-slot-0')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alex Worker'), findsWidgets);
    expect(find.textContaining('Free on first date'), findsOneWidget);
  });

  testWidgets('assign step dropdown shows Free beside worker name', (
    tester,
  ) async {
    final engagement = EngagementOut(
      id: 'eng-1',
      tenantId: 'tenant-1',
      contractorId: 'contractor-1',
      contractorName: 'Alex Worker',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => [engagement]);
    await controller.load();
    controller.setMode(UnifiedSupportMode.oneSession);
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('assign-slot-0')));
    await tester.tap(find.byKey(const ValueKey('assign-slot-0')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Alex Worker'), findsWidgets);
    expect(find.textContaining('Free'), findsOneWidget);
  });

  testWidgets('assign step dropdown shows Busy beside worker with overlapping shift', (
    tester,
  ) async {
    final shiftStart = DateTime(2026, 8, 13, 9);
    final shiftEnd = DateTime(2026, 8, 13, 12);
    final engagement = EngagementOut(
      id: 'eng-1',
      tenantId: 'tenant-1',
      contractorId: 'contractor-busy',
      contractorName: 'Busy Worker',
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => [engagement]);
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
    await controller.load();
    controller.setMode(UnifiedSupportMode.oneSession);
    controller.oneSessionStart.value = shiftStart;
    controller.oneSessionEnd.value = shiftEnd;
    controller.step.value = UnifiedSupportController.assignStep;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('assign-slot-0')));
    await tester.tap(find.byKey(const ValueKey('assign-slot-0')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Busy Worker'), findsWidgets);
    expect(find.textContaining(' · Busy'), findsOneWidget);
  });

  testWidgets('two slot picks survive availability rebuild and stay in controller', (
    tester,
  ) async {
    when(() => engagements.listTenantEngagements()).thenAnswer(
      (_) async => [
        EngagementOut(
          id: 'eng-1',
          tenantId: 'tenant-1',
          contractorId: 'contractor-1',
          contractorName: 'Alex Worker',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
        EngagementOut(
          id: 'eng-2',
          tenantId: 'tenant-1',
          contractorId: 'contractor-2',
          contractorName: 'Blair Worker',
          status: 'active',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await controller.load();
    controller.setMode(UnifiedSupportMode.oneSession);
    controller.requiredSlots.value = 2;
    controller.syncAssignSlots(controller.requiredSlots.value);
    controller.oneSessionStart.value = DateTime(2026, 8, 13, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 13, 12);
    controller.step.value = UnifiedSupportController.assignStep;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    Future<void> pick(int slot, String name) async {
      await tester.ensureVisible(find.byKey(ValueKey('assign-slot-$slot')));
      await tester.tap(find.byKey(ValueKey('assign-slot-$slot')));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(name).last);
      await tester.pumpAndSettle();
    }

    await pick(0, 'Alex Worker');
    await pick(1, 'Blair Worker');
    expect(controller.selectedContractorIds, ['contractor-1', 'contractor-2']);
    expect(find.textContaining('Selected: Alex Worker, Blair Worker'), findsOneWidget);

    // Simulate late availability reload that used to desync FormField display.
    controller.assignShifts.add(
      ShiftOut(
        id: 'shift-noise',
        tenantId: 'tenant-1',
        jobId: 'job-2',
        jobTitle: 'Other',
        clientId: 'client-2',
        clientName: 'Other',
        scheduledStart: DateTime(2026, 8, 13, 9),
        scheduledEnd: DateTime(2026, 8, 13, 12),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        assignments: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.selectedContractorIds, ['contractor-1', 'contractor-2']);
    expect(controller.filledContractorIds, ['contractor-1', 'contractor-2']);
    expect(find.textContaining('Selected: Alex Worker, Blair Worker'), findsOneWidget);
  });

  testWidgets('schedule step shows overlapping visit chip', (tester) async {
    final start = DateTime(2026, 8, 13, 9);
    final end = DateTime(2026, 8, 13, 12);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        clientId: any(named: 'clientId'),
        includeNested: any(named: 'includeNested'),
      ),
    ).thenAnswer(
      (_) async => [
        VisitOut(
          id: 'v-overlap',
          tenantId: 'tenant-1',
          jobId: 'job-1',
          contractorId: 'contractor-1',
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
    await controller.load();
    controller.setMode(UnifiedSupportMode.oneSession);
    controller.oneSessionStart.value = start;
    controller.oneSessionEnd.value = end;
    controller.step.value = UnifiedSupportController.scheduleStep;

    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overlapping visit…'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
