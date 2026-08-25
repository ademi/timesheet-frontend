import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';
import 'package:rostiq/features/jobs/utils/job_copy.dart';
import 'package:rostiq/features/jobs/utils/schedule_hours_warn.dart';
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

class _FakeOngoingSupportCreateRequest extends Fake
    implements OngoingSupportCreateRequest {}

class _FakeShiftCreateRequest extends Fake implements ShiftCreateRequest {}

class _FakeManualVisitCreateRequest extends Fake
    implements ManualVisitCreateRequest {}

class _FakeSupportItemPatch extends Fake implements SupportItemPatch {}

final _now = DateTime.utc(2026, 8, 13, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Lee',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

final _site = ClientSiteOut(
  id: 'site-1',
  tenantId: 'tenant-1',
  clientId: 'client-1',
  name: 'Home',
  geofenceRadiusM: 100,
  isPrimary: true,
  createdAt: _now,
  updatedAt: _now,
);

final _job = JobOut(
  id: 'job-1',
  tenantId: 'tenant-1',
  kind: 'standing',
  status: 'open',
  title: 'Sam Lee support',
  geofenceRadiusM: 100,
  geofenceMode: 'informational',
  createdAt: _now,
  updatedAt: _now,
  clientId: 'client-1',
);

final _jobWithSupport = JobOut(
  id: 'job-1',
  tenantId: 'tenant-1',
  kind: 'standing',
  status: 'open',
  title: 'Sam Lee support',
  geofenceRadiusM: 100,
  geofenceMode: 'informational',
  createdAt: _now,
  updatedAt: _now,
  clientId: 'client-1',
  supportItemCode: '01_011_0107_1_1',
  supportItemName: 'Self care',
);

final _eng = EngagementOut(
  id: 'eng-1',
  tenantId: 'tenant-1',
  contractorId: 'contractor-1',
  contractorName: 'Alex Worker',
  status: 'active',
  createdAt: _now,
  updatedAt: _now,
);

final _ongoingOut = OngoingSupportOut(
  job: _job,
  rule: RecurrenceRuleOut(
    id: 'rule-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    requiredSlots: 1,
    rrule: 'FREQ=WEEKLY;BYDAY=MO',
    dtstart: _now,
    timeWindows: const [TimeWindow(startTime: '09:00', endTime: '12:00')],
    isActive: true,
    createdAt: _now,
    updatedAt: _now,
  ),
  horizon: HorizonOut.empty,
);

void main() {
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockEngagementsRepository engagements;
  late _MockShiftsRepository shifts;
  late _MockVisitsRepository visits;
  late _MockSessionService session;
  late List<({String route, dynamic arguments})> navigations;

  setUpAll(() {
    registerFallbackValue(_FakeOngoingSupportCreateRequest());
    registerFallbackValue(_FakeShiftCreateRequest());
    registerFallbackValue(_FakeManualVisitCreateRequest());
    registerFallbackValue(_FakeSupportItemPatch());
    registerFallbackValue(<TaskTemplateItem>[]);
    registerFallbackValue(_now);
  });

  setUp(() {
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    shifts = _MockShiftsRepository();
    visits = _MockVisitsRepository();
    session = _MockSessionService();
    navigations = [];
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
    when(() => session.tenantTimezone).thenReturn(RxnString());
    when(() => clients.listSites('client-1')).thenAnswer((_) async => [_site]);
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
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);
    when(
      () => jobs.listFormTemplates(tenantLevel: true),
    ).thenAnswer((_) async => []);
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

  tearDown(() {
    tenantUtcOffsetOverride = null;
    Get.reset();
  });

  UnifiedSupportController build({
    UnifiedSupportArgs? args,
  }) {
    return UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
      visitsRepository: visits,
      session: session,
      args: args ??
          UnifiedSupportArgs.forClient(
            _client,
            mode: UnifiedSupportMode.ongoing,
          ),
      onNavigate: (route, arguments) {
        navigations.add((route: route, arguments: arguments));
      },
    );
  }

  test('bootstrap does not load engagements until assign step', () async {
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => [_eng]);
    final c = build();
    await c.load();
    verifyNever(() => engagements.listTenantEngagements());
    c.step.value = UnifiedSupportController.assignStep;
    await c.ensureEngagementsLoaded();
    verify(() => engagements.listTenantEngagements()).called(1);
    expect(c.engagements, [_eng]);
  });

  test('formatSupportTimeOfDay pads hours and minutes', () {
    expect(formatSupportTimeOfDay(const TimeOfDay(hour: 9, minute: 5)), '09:05');
  });

  test('step validation requires mode and client', () async {
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    final controller = build(args: const UnifiedSupportArgs());
    await controller.load();

    expect(controller.canGoNext(), isFalse);
    expect(controller.errorMessage.value, contains('one session or ongoing'));

    controller.setMode(UnifiedSupportMode.oneSession);
    expect(controller.canGoNext(), isFalse);
    expect(controller.errorMessage.value, contains('Select a client'));
  });

  test('ongoing submit posts create and navigates to roster with client_id',
      () async {
    when(() => jobs.createOngoingSupport(any())).thenAnswer((_) async => _ongoingOut);

    final controller = build();
    await controller.load();

    expect(controller.client.value?.id, 'client-1');
    expect(controller.selectedSiteId.value, 'site-1');
    expect(controller.titleCtrl.text, defaultOngoingTitle('Sam Lee'));

    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;
    expect(captured.clientId, 'client-1');
    expect(captured.clientSiteId, 'site-1');
    expect(captured.timeWindows.single.startTime, '09:00');
    expect(navigations, hasLength(1));
    expect(navigations.single.route, AppRoutes.staffVisits);
    final args = navigations.single.arguments as Map;
    expect(args['client_id'], 'client-1');
    expect(args['job_id'], 'job-1');
  });

  test('one session submit ensures support then creates shift', () async {
    when(() => jobs.ensureOngoingSupport('client-1'))
        .thenAnswer((_) async => _job);
    when(() => shifts.createShift(any())).thenAnswer(
      (_) async => ShiftOut(
        id: 'shift-1',
        tenantId: 'tenant-1',
        jobId: 'job-1',
        jobTitle: 'Sam Lee support',
        scheduledStart: _now,
        scheduledEnd: _now.add(const Duration(hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: _now,
        updatedAt: _now,
      ),
    );

    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();

    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    verify(() => jobs.ensureOngoingSupport('client-1')).called(1);
    final shiftReq = verify(() => shifts.createShift(captureAny()))
        .captured
        .single as ShiftCreateRequest;
    expect(shiftReq.jobId, 'job-1');
    expect(shiftReq.status, 'published');
    expect(navigations.single.route, AppRoutes.staffVisits);
  });

  test('blocks submit when client has no sites', () async {
    when(() => clients.listSites('client-1')).thenAnswer((_) async => []);

    final controller = build();
    await controller.load();

    expect(controller.blocksWithoutSites, isTrue);
    controller.step.value = 1;
    expect(controller.canGoNext(), isFalse);
    expect(controller.errorMessage.value, contains('location'));
  });

  test('required slots steppers clamp between 1 and 20', () {
    final controller = build();
    controller.requiredSlots.value = 1;
    controller.decrementSlots();
    expect(controller.requiredSlots.value, 1);
    controller.requiredSlots.value = 20;
    controller.incrementSlots();
    expect(controller.requiredSlots.value, 20);
  });

  test('setRequiredSlots parses digits and clamps', () {
    final controller = build();
    controller.setRequiredSlots('15');
    expect(controller.requiredSlots.value, 15);
    controller.setRequiredSlots('99');
    expect(controller.requiredSlots.value, 20);
    controller.setRequiredSlots('');
    expect(controller.requiredSlots.value, 1);
  });

  test('appendCatalogueTask stamps support item code on template', () {
    final c = build();
    c.appendCatalogueTask(
      code: '01_011_0107_1_1',
      name: 'Assistance With Self-Care Activities - Standard - Weekday Daytime',
    );
    expect(c.taskTemplate.first.supportItemCode, '01_011_0107_1_1');
    expect(c.taskTemplate.first.title, contains('Self-Care'));
  });

  test('removeTaskAt drops item so codes cannot desync', () {
    final c = build();
    c.appendCatalogueTask(code: '01_011_0107_1_1', name: 'Self care');
    c.appendCustomTask('Meal prep');
    c.removeTaskAt(0);
    expect(c.taskTemplate.single.title, 'Meal prep');
    expect(c.taskTemplate.single.supportItemCode, isNull);
  });

  test('ongoing submit includes care plan task template', () async {
    when(() => jobs.createOngoingSupport(any())).thenAnswer((_) async => _ongoingOut);

    final controller = build();
    await controller.load();
    controller.appendCatalogueTask(
      code: '01_011_0107_1_1',
      name: 'Personal care',
    );
    controller.appendCustomTask('Meal prep');
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;
    expect(captured.taskTemplate, hasLength(2));
    expect(captured.taskTemplate[0].title, 'Personal care');
    expect(captured.taskTemplate[0].supportItemCode, '01_011_0107_1_1');
    expect(captured.taskTemplate[1].title, 'Meal prep');
    expect(captured.taskTemplate[1].supportItemCode, isNull);
    expect(captured.toJson()['task_template'], [
      {
        'title': 'Personal care',
        'sort_order': 0,
        'support_item_code': '01_011_0107_1_1',
      },
      {
        'title': 'Meal prep',
        'sort_order': 1,
      },
    ]);
  });

  test('schedule warn prefers session tenantTimezone', () async {
    when(() => session.tenantTimezone).thenReturn(RxnString('Australia/Sydney'));
    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    Get.put(controller);
    await Future<void>.delayed(Duration.zero);

    expect(controller.scheduleWarnTimezone.value, 'Australia/Sydney');
    controller.oneSessionStart.value = DateTime(2026, 8, 22, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 22, 12);
    expect(controller.showScheduleHoursWarn, isTrue);
  });

  test('ongoing submit horizon uses session tenantTimezone', () async {
    tenantUtcOffsetOverride = (tz, _) {
      if (tz == 'Pacific/Honolulu') return const Duration(hours: -10);
      return Duration.zero;
    };
    when(() => session.tenantTimezone).thenReturn(RxnString('Pacific/Honolulu'));
    when(() => jobs.createOngoingSupport(any())).thenAnswer((_) async => _ongoingOut);

    final controller = build();
    await controller.load();
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;
    final now = DateTime.now().toUtc();
    final expected = tenantHorizonWindowUtc(now, 'Pacific/Honolulu');
    final deviceLocal = tenantHorizonWindowUtc(now, null);
    expect(captured.horizonFrom, expected.from);
    expect(captured.horizonTo, expected.to);
    expect(captured.horizonFrom, isNot(deviceLocal.from));
  });

  test('showScheduleHoursWarn true for Saturday one session', () async {
    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();
    controller.oneSessionStart.value = DateTime(2026, 8, 22, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 22, 12);

    expect(controller.showScheduleHoursWarn, isTrue);
  });

  test('canGoNext still true with atypical schedule hours', () async {
    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();
    controller.step.value = 2;
    controller.oneSessionStart.value = DateTime(2026, 8, 22, 9);
    controller.oneSessionEnd.value = DateTime(2026, 8, 22, 12);

    expect(controller.showScheduleHoursWarn, isTrue);
    expect(controller.canGoNext(), isTrue);
  });

  test('showNdisCapturePrompt when Patient has no NDIS number', () async {
    final controller = build();
    await controller.load();

    expect(controller.showNdisCapturePrompt, isTrue);
    expect(controller.clientNdisNumber, isNull);
  });

  test('showNdisCapturePrompt false when NDIS fact present', () async {
    when(() => clients.getClientProfile(any())).thenAnswer(
      (_) async => const ClientProfileBundle(
        clientType: ClientTypeOut(
          id: 'type-1',
          code: 'patient',
          name: 'Patient',
          isActive: true,
          sortOrder: 0,
        ),
        facts: [
          ClientProfileFactOut(requirementKey: 'ndis', valueJson: '430000000'),
        ],
      ),
    );

    final controller = build();
    await controller.load();

    expect(controller.showNdisCapturePrompt, isFalse);
    expect(controller.clientNdisNumber, '430000000');
  });

  test('canGoNext requires title on details step for ongoing', () async {
    final controller = build();
    await controller.load();
    controller.step.value = UnifiedSupportController.detailsStep;
    controller.titleCtrl.clear();

    expect(controller.canGoNext(), isFalse);
    expect(controller.errorMessage.value, contains('Title'));

    controller.titleCtrl.text = 'Sam Lee support';
    expect(controller.canGoNext(), isTrue);
  });

  test('nextStep loads engagements when entering assign step', () async {
    when(() => engagements.listTenantEngagements())
        .thenAnswer((_) async => [_eng]);
    final controller = build();
    await controller.load();
    controller.step.value = UnifiedSupportController.detailsStep;

    controller.nextStep();

    expect(controller.step.value, UnifiedSupportController.assignStep);
    verify(() => engagements.listTenantEngagements()).called(1);
  });

  test('surfaces AppFailure from ongoing create', () async {
    when(() => jobs.createOngoingSupport(any())).thenThrow(
      const AppFailure(
        code: 'standing_job_exists',
        message: 'This client already has ongoing support.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    final controller = build();
    await controller.load();
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    expect(
      controller.errorMessage.value,
      'This client already has ongoing support.',
    );
    expect(navigations, isEmpty);
  });

  test('assign step exposes requiredSlots contractor slots', () {
    final c = build();
    c.requiredSlots.value = 3;
    c.syncAssignSlots();
    expect(c.selectedContractorIds.length, 3);
    expect(c.selectedContractorIds, everyElement(isNull));
  });

  test('syncAssignSlots keeps existing picks when growing and truncates', () {
    final c = build();
    c.requiredSlots.value = 1;
    c.syncAssignSlots();
    c.selectContractorForSlot(0, 'contractor-1');
    c.requiredSlots.value = 3;
    c.syncAssignSlots();
    expect(c.selectedContractorIds, ['contractor-1', null, null]);
    c.requiredSlots.value = 1;
    c.syncAssignSlots();
    expect(c.selectedContractorIds, ['contractor-1']);
  });

  test('rejects duplicate contractor across slots', () {
    final c = build();
    c.requiredSlots.value = 2;
    c.syncAssignSlots();
    expect(c.selectContractorForSlot(0, 'contractor-1'), isTrue);
    expect(c.selectContractorForSlot(1, 'contractor-1'), isFalse);
    expect(c.selectedContractorIds[1], isNull);
    expect(c.errorMessage.value, contains('already'));
  });

  test('submit ongoing sends all selected contractor_ids', () async {
    when(() => jobs.createOngoingSupport(any()))
        .thenAnswer((_) async => _ongoingOut);

    final controller = build();
    await controller.load();
    controller.requiredSlots.value = 2;
    controller.syncAssignSlots();
    controller.selectContractorForSlot(0, 'contractor-1');
    controller.selectContractorForSlot(1, 'contractor-2');
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;
    expect(captured.requiredSlots, 2);
    expect(captured.contractorIds, ['contractor-1', 'contractor-2']);
    expect(navigations, hasLength(1));
  });

  test('submit ongoing omits unfilled slots from contractor_ids', () async {
    when(() => jobs.createOngoingSupport(any()))
        .thenAnswer((_) async => _ongoingOut);

    final controller = build();
    await controller.load();
    controller.requiredSlots.value = 2;
    controller.syncAssignSlots();
    controller.selectContractorForSlot(0, 'contractor-1');
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;
    expect(captured.requiredSlots, 2);
    expect(captured.contractorIds, ['contractor-1']);
  });

  test('one session always createShift then N assignShift, never manual visit',
      () async {
    when(() => jobs.ensureOngoingSupport('client-1'))
        .thenAnswer((_) async => _job);
    when(() => shifts.createShift(any())).thenAnswer((_) async => _publishedShift());
    when(
      () => shifts.assignShift(
        shiftId: any(named: 'shiftId'),
        contractorId: any(named: 'contractorId'),
        taskTemplate: any(named: 'taskTemplate'),
      ),
    ).thenAnswer(
      (invocation) async => _publishedShift(
        assignments: [
          ShiftAssignmentOut(
            id: 'asg-1',
            contractorId: invocation.namedArguments[#contractorId] as String,
            contractorName: 'Worker',
            visitId: 'visit-1',
            source: 'staff_assign',
            status: 'active',
          ),
        ],
        openSlots: 0,
      ),
    );

    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();
    controller.requiredSlots.value = 2;
    controller.syncAssignSlots();
    controller.selectContractorForSlot(0, 'contractor-1');
    controller.selectContractorForSlot(1, 'contractor-2');
    controller.appendCustomTask('Personal care');
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    verify(() => jobs.ensureOngoingSupport('client-1')).called(1);
    final shiftReq = verify(() => shifts.createShift(captureAny()))
        .captured
        .single as ShiftCreateRequest;
    expect(shiftReq.requiredSlots, 2);
    expect(shiftReq.status, 'published');
    verify(
      () => shifts.assignShift(
        shiftId: 'shift-1',
        contractorId: 'contractor-1',
        taskTemplate: any(named: 'taskTemplate'),
      ),
    ).called(1);
    verify(
      () => shifts.assignShift(
        shiftId: 'shift-1',
        contractorId: 'contractor-2',
        taskTemplate: any(named: 'taskTemplate'),
      ),
    ).called(1);
    verifyNever(() => jobs.createManualVisit(any(), any()));
    expect(navigations, hasLength(1));
  });

  test('one session assignShift sends task_template from task list', () async {
    when(() => jobs.ensureOngoingSupport('client-1'))
        .thenAnswer((_) async => _job);
    when(() => shifts.createShift(any())).thenAnswer((_) async => _publishedShift());
    when(
      () => shifts.assignShift(
        shiftId: any(named: 'shiftId'),
        contractorId: any(named: 'contractorId'),
        taskTemplate: any(named: 'taskTemplate'),
      ),
    ).thenAnswer((_) async => _publishedShift(openSlots: 0));

    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();
    controller.syncAssignSlots();
    controller.selectContractorForSlot(0, 'contractor-1');
    controller.appendCustomTask('Personal care');
    controller.appendCustomTask('Meal prep');
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    final captured = verify(
      () => shifts.assignShift(
        shiftId: 'shift-1',
        contractorId: 'contractor-1',
        taskTemplate: captureAny(named: 'taskTemplate'),
      ),
    ).captured.single as List<TaskTemplateItem>;
    expect(captured.map((t) => t.title), ['Personal care', 'Meal prep']);
    expect(captured.map((t) => t.sortOrder), [0, 1]);
  });

  test('one session with one worker still uses createShift plus assignShift',
      () async {
    when(() => jobs.ensureOngoingSupport('client-1'))
        .thenAnswer((_) async => _job);
    when(() => shifts.createShift(any())).thenAnswer((_) async => _publishedShift());
    when(
      () => shifts.assignShift(
        shiftId: any(named: 'shiftId'),
        contractorId: any(named: 'contractorId'),
        taskTemplate: any(named: 'taskTemplate'),
      ),
    ).thenAnswer((_) async => _publishedShift(openSlots: 0));

    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();
    controller.syncAssignSlots();
    controller.selectContractorForSlot(0, 'contractor-1');
    controller.appendCustomTask('Meal prep');
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    verify(() => shifts.createShift(any())).called(1);
    verify(
      () => shifts.assignShift(
        shiftId: 'shift-1',
        contractorId: 'contractor-1',
        taskTemplate: any(named: 'taskTemplate'),
      ),
    ).called(1);
    verifyNever(() => jobs.createManualVisit(any(), any()));
  });

  test('support item stamp failure blocks navigate and skip roster', () async {
    when(() => jobs.ensureOngoingSupport('client-1'))
        .thenAnswer((_) async => _job);
    when(() => jobs.patchJobSupportItem(any(), any())).thenThrow(
      const AppFailure(
        code: 'support_item_not_in_catalogue',
        message: 'Could not save the NDIS support item.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    final controller = build(
      args: UnifiedSupportArgs.forClient(
        _client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
    await controller.load();
    controller.setSupportItem(
      supportItemCode: '01_011_0107_1_1',
      supportItemName: 'Self care',
    );
    controller.step.value = UnifiedSupportController.assignStep;
    await controller.submit();

    expect(
      controller.errorMessage.value,
      'Could not save the NDIS support item.',
    );
    expect(navigations, isEmpty);
    verifyNever(() => shifts.createShift(any()));
    verifyNever(() => jobs.createManualVisit(any(), any()));
  });

  test('nextStep syncs assign slots when entering workers step', () async {
    final controller = build();
    await controller.load();
    controller.requiredSlots.value = 2;
    controller.step.value = UnifiedSupportController.detailsStep;

    controller.nextStep();

    expect(controller.step.value, UnifiedSupportController.assignStep);
    expect(controller.selectedContractorIds.length, 2);
  });

  test('selectClient prefills support item from standing job', () async {
    when(() => jobs.getOngoingSupport('client-1')).thenAnswer(
      (_) async => _jobWithSupport,
    );
    final c = build();
    await c.selectClient(_client);
    expect(c.supportItemCode.value, '01_011_0107_1_1');
    expect(c.supportItemName.value, isNotEmpty);
    expect(c.supportItemPrefilledFromStanding, isTrue);
  });

  test('selectClient leaves support item empty when no standing job', () async {
    when(() => jobs.getOngoingSupport('client-1')).thenThrow(
      const AppFailure(
        code: 'not_found',
        message: 'No ongoing support.',
        presentation: AppFailurePresentation.inline,
        statusCode: 404,
      ),
    );
    final c = build();
    await c.selectClient(_client);
    expect(c.supportItemCode.value, isNull);
    expect(c.supportItemName.value, isNull);
    expect(c.supportItemPrefilledFromStanding, isFalse);
  });

  test('selectClient does not overwrite user-changed support item', () async {
    when(() => jobs.getOngoingSupport('client-1')).thenAnswer(
      (_) async => _jobWithSupport,
    );
    final c = build();
    c.setSupportItem(
      supportItemCode: 'user-code',
      supportItemName: 'User choice',
      userInitiated: true,
    );
    await c.selectClient(_client);
    expect(c.supportItemCode.value, 'user-code');
    expect(c.supportItemName.value, 'User choice');
    expect(c.supportItemPrefilledFromStanding, isFalse);
  });
}

ShiftOut _publishedShift({
  List<ShiftAssignmentOut> assignments = const [],
  int requiredSlots = 1,
  int openSlots = 1,
}) {
  return ShiftOut(
    id: 'shift-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Sam Lee support',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 2)),
    requiredSlots: requiredSlots,
    openSlots: openSlots,
    status: 'published',
    assignments: assignments,
    createdAt: _now,
    updatedAt: _now,
  );
}
