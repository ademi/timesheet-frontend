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
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/controllers/unified_support_controller.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/jobs/utils/job_copy.dart';
import 'package:rostiq/features/jobs/utils/schedule_hours_warn.dart';
import 'package:rostiq/features/jobs/utils/unified_support_args.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeOngoingSupportCreateRequest extends Fake
    implements OngoingSupportCreateRequest {}

class _FakeShiftCreateRequest extends Fake implements ShiftCreateRequest {}

class _FakeManualVisitCreateRequest extends Fake
    implements ManualVisitCreateRequest {}

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
  late _MockSessionService session;
  late List<({String route, dynamic arguments})> navigations;

  setUpAll(() {
    registerFallbackValue(_FakeOngoingSupportCreateRequest());
    registerFallbackValue(_FakeShiftCreateRequest());
    registerFallbackValue(_FakeManualVisitCreateRequest());
  });

  setUp(() {
    Get.testMode = true;
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    engagements = _MockEngagementsRepository();
    shifts = _MockShiftsRepository();
    session = _MockSessionService();
    navigations = [];
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
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
  });

  tearDown(Get.reset);

  UnifiedSupportController build({
    UnifiedSupportArgs? args,
  }) {
    return UnifiedSupportController(
      jobsRepository: jobs,
      clientsRepository: clients,
      engagementsRepository: engagements,
      shiftsRepository: shifts,
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

    controller.step.value = 3;
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

    controller.step.value = 3;
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

  test('ongoing submit includes care plan task template', () async {
    when(() => jobs.createOngoingSupport(any())).thenAnswer((_) async => _ongoingOut);

    final controller = build();
    await controller.load();
    controller.taskTitlesCtrl.text = 'Personal care\nMeal prep';
    controller.step.value = 3;
    await controller.submit();

    final captured = verify(
      () => jobs.createOngoingSupport(captureAny()),
    ).captured.single as OngoingSupportCreateRequest;
    expect(captured.taskTemplate, hasLength(2));
    expect(captured.taskTemplate[0].title, 'Personal care');
    expect(captured.taskTemplate[1].title, 'Meal prep');
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
    controller.step.value = 3;
    await controller.submit();

    expect(
      controller.errorMessage.value,
      'This client already has ongoing support.',
    );
    expect(navigations, isEmpty);
  });
}
