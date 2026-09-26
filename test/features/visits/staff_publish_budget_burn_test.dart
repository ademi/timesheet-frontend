import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
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

class _FakeShiftPublishRequest extends Fake implements ShiftPublishRequest {}

final _now = DateTime.utc(2026, 9, 26, 9);

ShiftOut _draftShift({String id = 'shift-1'}) {
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
    status: 'draft',
    assignments: const [],
    createdAt: _now,
    updatedAt: _now,
  );
}

ShiftOut _publishedShift({String id = 'shift-1'}) {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockClientsRepository clients;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
    registerFallbackValue(_FakeHorizonRequest());
    registerFallbackValue(_FakeShiftPublishRequest());
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
  });

  tearDown(Get.reset);

  StaffVisitsController build({
    Future<String?> Function({required List<String> reasons})?
    promptBurnOverride,
  }) {
    final controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: jobs,
      engagementsRepository: engagements,
      clientsRepository: clients,
      session: session,
      promptBurnOverride: promptBurnOverride,
    );
    controller.selectedShift.value = _draftShift();
    return controller;
  }

  test('budget_burn_blocked uses budget override prompt then republishes', () async {
    var publishCalls = 0;
    var burnPromptCalls = 0;
    List<String>? burnPromptReasons;
    when(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      publishCalls++;
      final body = invocation.namedArguments[#body] as ShiftPublishRequest?;
      if (body?.overrideReason == null || body!.overrideReason!.isEmpty) {
        throw const AppFailure(
          code: 'budget_burn_blocked',
          message: 'Publishing would exceed plan budget thresholds.',
          presentation: AppFailurePresentation.inline,
          eligibilityReasons: ['hard_block: Maya / core'],
        );
      }
      return _publishedShift();
    });

    final controller = build(
      promptBurnOverride: ({required List<String> reasons}) async {
        burnPromptCalls++;
        burnPromptReasons = List<String>.from(reasons);
        return 'SC confirmed statement remaining';
      },
    );

    await controller.publishSelectedShift();

    expect(publishCalls, 2);
    expect(burnPromptCalls, 1);
    expect(burnPromptReasons, ['hard_block: Maya / core']);
    expect(controller.selectedShift.value?.status, 'published');
    verify(
      () => shifts.publishShift(
        'shift-1',
        body: any(
          named: 'body',
          that: isA<ShiftPublishRequest>().having(
            (b) => b.overrideReason,
            'overrideReason',
            'SC confirmed statement remaining',
          ),
        ),
      ),
    ).called(1);
  });

  test('credential_gate_blocked does not call budget override prompt', () async {
    var burnPromptCalls = 0;
    when(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).thenThrow(
      const AppFailure(
        code: 'credential_gate_blocked',
        message: 'Screening blocked',
        presentation: AppFailurePresentation.inline,
        eligibilityReasons: ['wwcc: expired'],
      ),
    );

    final controller = build(
      promptBurnOverride: ({required List<String> reasons}) async {
        burnPromptCalls++;
        return 'should-not-be-used';
      },
    );

    await controller.publishSelectedShift();

    expect(burnPromptCalls, 0);
    expect(controller.credentialGateReasons, ['wwcc: expired']);
    // testMode credential prompt returns null → no republish
    verify(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).called(1);
  });
}
