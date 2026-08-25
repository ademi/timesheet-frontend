import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/jobs/views/unified_support_view.dart';
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

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

class _FakeOngoingSupportCreateRequest extends Fake
    implements OngoingSupportCreateRequest {}

void main() {
  late UnifiedSupportController controller;
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockShiftsRepository shifts;
  late _MockVisitsRepository visits;
  late _MockSessionService session;
  late _MockNdisCatalogueRepository ndisCatalogue;
  late List<({String route, dynamic arguments})> navigations;

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
  final job = JobOut(
    id: 'job-1',
    tenantId: 'tenant-1',
    kind: 'standing',
    status: 'open',
    title: 'Sam Lee support',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    createdAt: now,
    updatedAt: now,
    clientId: 'client-1',
  );
  final ongoingOut = OngoingSupportOut(
    job: job,
    rule: RecurrenceRuleOut(
      id: 'rule-1',
      tenantId: 'tenant-1',
      jobId: 'job-1',
      requiredSlots: 2,
      rrule: 'FREQ=WEEKLY;BYDAY=MO',
      dtstart: now,
      timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
      isActive: true,
      createdAt: now,
      updatedAt: now,
    ),
    horizon: HorizonOut.empty,
  );

  setUpAll(() {
    registerFallbackValue(_FakeOngoingSupportCreateRequest());
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
    ndisCatalogue = _MockNdisCatalogueRepository();
    navigations = [];

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
    when(() => jobs.createOngoingSupport(any()))
        .thenAnswer((_) async => ongoingOut);
    when(() => ndisCatalogue.fetchAllActiveItems()).thenAnswer(
      (_) async => const [
        NdisCatalogueItemOut(
          supportItemNumber: '01_011_0107_1_1',
          supportItemName:
              'Assistance With Self-Care Activities - Standard - Weekday Daytime',
          unit: 'H',
        ),
      ],
    );
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

    Get.put<NdisCatalogueRepository>(ndisCatalogue);

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
      onNavigate: (route, arguments) {
        navigations.add((route: route, arguments: arguments));
      },
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  Future<void> pumpView(WidgetTester tester) async {
    await controller.load();
    await tester.pumpWidget(
      const GetMaterialApp(home: UnifiedSupportView()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Next'));
    await tester.pumpAndSettle();
  }

  Future<void> selectWorker(
    WidgetTester tester, {
    required int slot,
    required String workerName,
  }) async {
    await tester.ensureVisible(find.byKey(ValueKey('assign-slot-$slot')));
    await tester.tap(find.byKey(ValueKey('assign-slot-$slot')));
    await tester.pumpAndSettle();
    // Items are "Name · Free/Busy/Leave" (single-line to avoid dropdown overflow).
    await tester.tap(find.textContaining(workerName).last);
    await tester.pumpAndSettle();
  }

  testWidgets('walks five-step flow and submits ongoing with two workers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpView(tester);

    // Step 0 — Type (mode + client from args)
    expect(find.text('Support type'), findsOneWidget);
    expect(find.text('Ongoing support'), findsOneWidget);
    await tapNext(tester);

    // Step 1 — Location (primary site auto-selected)
    expect(find.text('Where will this support happen?'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    await tapNext(tester);

    // Step 2 — Schedule (set two required worker slots)
    expect(find.text('Repeats'), findsOneWidget);
    final slotsField = find.descendant(
      of: find.widgetWithText(InputDecorator, 'Required workers'),
      matching: find.byType(TextField),
    );
    await tester.ensureVisible(slotsField);
    await tester.enterText(slotsField, '2');
    await tester.pumpAndSettle();
    expect(controller.requiredSlots.value, 2);
    await tapNext(tester);

    // Step 3 — Details (presets + catalogue-backed care plan task)
    expect(find.text('Care plan tasks'), findsOneWidget);
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Add preset task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal care').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'Add preset task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Community access').last);
    await tester.pumpAndSettle();
    expect(
      controller.taskTemplate.map((t) => t.title),
      ['Personal care', 'Community access'],
    );
    expect(
      controller.taskTemplate.every((t) => t.supportItemCode == null),
      isTrue,
    );

    await tester.ensureVisible(find.byKey(const Key('add-from-catalogue')));
    await tester.tap(find.byKey(const Key('add-from-catalogue')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('catalogue-task-picker-dialog')),
        matching: find.textContaining('Self-Care'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.taskTemplate, hasLength(3));
    expect(controller.taskTemplate.last.supportItemCode, '01_011_0107_1_1');
    await tapNext(tester);

    // Step 4 — Workers (assign two contractors, then submit)
    expect(find.text('Assign up to 2 workers for this support (optional).'),
        findsOneWidget);
    expect(find.text('Worker 1 (optional)'), findsOneWidget);
    expect(find.text('Worker 2 (optional)'), findsOneWidget);
    await selectWorker(tester, slot: 0, workerName: 'Alex Worker');
    await selectWorker(tester, slot: 1, workerName: 'Blair Worker');

    await tester.tap(find.text('Save and fill roster'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;

    expect(captured.contractorIds, hasLength(2));
    expect(captured.contractorIds, ['contractor-1', 'contractor-2']);
    expect(captured.requiredSlots, 2);
    expect(captured.clientId, 'client-1');
    expect(captured.clientSiteId, 'site-1');

    expect(captured.taskTemplate, hasLength(3));
    expect(captured.taskTemplate.map((t) => t.title), [
      'Personal care',
      'Community access',
      'Assistance With Self-Care Activities - Standard - Weekday Daytime',
    ]);
    expect(captured.taskTemplate[0].supportItemCode, isNull);
    expect(captured.taskTemplate[1].supportItemCode, isNull);
    expect(captured.taskTemplate[2].supportItemCode, '01_011_0107_1_1');

    expect(navigations, hasLength(1));
  });
}
