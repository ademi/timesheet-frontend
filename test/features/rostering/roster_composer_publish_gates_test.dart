import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/constants/app_permissions.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/rostering/data/composer_facade.dart';
import 'package:rostiq/features/rostering/data/composer_models.dart';
import 'package:rostiq/features/rostering/domain/roster_composer_args.dart';
import 'package:rostiq/features/rostering/presentation/composer/roster_composer_controller.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeShiftPublishRequest extends Fake implements ShiftPublishRequest {}

ShiftOut _draftShift({String id = 'shift-1'}) => ShiftOut(
  id: id,
  tenantId: 't1',
  jobId: 'job-1',
  jobTitle: 'Support',
  clientId: 'c1',
  scheduledStart: DateTime.utc(2026, 10, 4, 9),
  scheduledEnd: DateTime.utc(2026, 10, 4, 12),
  requiredSlots: 1,
  openSlots: 1,
  status: 'draft',
  participants: const [
    ShiftParticipantOut(
      id: 'sp1',
      participantId: 'c1',
      participantName: 'Sam',
      status: 'active',
      attendance: 'present',
      allocationValue: 100,
    ),
  ],
  createdAt: DateTime.utc(2026, 10, 4),
  updatedAt: DateTime.utc(2026, 10, 4),
);

ShiftOut _publishedShift({String id = 'shift-1'}) => ShiftOut(
  id: id,
  tenantId: 't1',
  jobId: 'job-1',
  jobTitle: 'Support',
  clientId: 'c1',
  scheduledStart: DateTime.utc(2026, 10, 4, 9),
  scheduledEnd: DateTime.utc(2026, 10, 4, 12),
  requiredSlots: 1,
  openSlots: 1,
  status: 'published',
  createdAt: DateTime.utc(2026, 10, 4),
  updatedAt: DateTime.utc(2026, 10, 4),
);

ClientOut _client(String id) => ClientOut(
  id: id,
  tenantId: 't1',
  fullName: 'Sam',
  status: 'active',
  metadata: const {},
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late ComposerFacade facade;

  setUpAll(() {
    registerFallbackValue(
      ShiftCreateRequest(
        jobId: 'j',
        scheduledStart: DateTime.utc(2026, 1, 1),
        scheduledEnd: DateTime.utc(2026, 1, 1, 1),
      ),
    );
    registerFallbackValue(const ShiftPatchRequest());
    registerFallbackValue(
      const ShiftParticipantsReplaceRequest(participants: []),
    );
    registerFallbackValue(_FakeShiftPublishRequest());
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    facade = ComposerFacade(shifts: shifts, jobs: jobs);

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantTimezone).thenReturn(RxnString('Australia/Sydney'));
    when(() => clients.listClients()).thenAnswer((_) async => [_client('c1')]);
    when(() => clients.getClient(any())).thenAnswer((_) async => _client('c1'));
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut());
    when(
      () => shifts.fetchPlaceOptions(participantIds: any(named: 'participantIds')),
    ).thenAnswer(
      (_) async => const PlaceOptionsOut(
        branches: [PlaceBranchOption(id: 'b1', name: 'Centre')],
      ),
    );
    when(
      () => jobs.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => []);
    when(
      () => shifts.fetchAssignContext(
        from: any(named: 'from'),
        to: any(named: 'to'),
        clientId: any(named: 'clientId'),
      ),
    ).thenAnswer((_) async => const AssignContextOut());
    when(() => shifts.getComposer('shift-1')).thenAnswer(
      (_) async => ComposerShiftOut(shift: _draftShift()),
    );
    when(() => shifts.patchDraftShift(any(), any())).thenAnswer(
      (_) async => _draftShift(),
    );
    when(() => shifts.putParticipants(any(), any())).thenAnswer(
      (_) async => _draftShift(),
    );
    when(
      () => shifts.assignShiftBatch(
        shiftId: any(named: 'shiftId'),
        contractorIds: any(named: 'contractorIds'),
        taskTemplate: any(named: 'taskTemplate'),
        overrideReason: any(named: 'overrideReason'),
      ),
    ).thenAnswer((_) async => _draftShift());
    when(() => shifts.listFormOverrides(any())).thenAnswer((_) async => []);
    when(() => shifts.listTravel(any())).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  Future<RosterComposerController> readyComposer({
    Future<String?> Function({required List<String> reasons})?
    promptBurnOverride,
    Future<String?> Function({
      required List<String> reasons,
      required String title,
    })?
    promptCredentialGateOverride,
  }) async {
    final c = RosterComposerController(
      facade: facade,
      clientsRepository: clients,
      session: session,
      args: const RosterComposerArgs(shiftId: 'shift-1'),
      onNavigate: (_, __) {},
      confirmPublishOpenSlots: (_) async => true,
      promptBurnOverride: promptBurnOverride,
      promptCredentialGateOverride: promptCredentialGateOverride,
    );
    Get.put(c);
    await c.retryHydrate();
    c.setPlace(const ShiftPlaceIn.branch('b1'));
    c.draft.value = c.draft.value.copyWith(
      participantIds: ['c1'],
      clientId: 'c1',
      supportItemCode: '01_011_0107_1_1',
      contractorIds: const [],
    );
    return c;
  }

  test('budget_burn_blocked prompts then republishes with budget override', () async {
    var publishCalls = 0;
    var burnPromptCalls = 0;
    when(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      publishCalls++;
      final body = invocation.namedArguments[#body] as ShiftPublishRequest?;
      if (body?.budgetOverrideReason == null ||
          body!.budgetOverrideReason!.isEmpty) {
        throw const AppFailure(
          code: 'budget_burn_blocked',
          message: 'Publishing would exceed plan budget thresholds.',
          presentation: AppFailurePresentation.inline,
          eligibilityReasons: ['hard_block: Maya / core'],
        );
      }
      return _publishedShift();
    });

    final c = await readyComposer(
      promptBurnOverride: ({required List<String> reasons}) async {
        burnPromptCalls++;
        expect(reasons, ['hard_block: Maya / core']);
        return 'SC confirmed statement remaining';
      },
    );

    final ok = await c.publish();

    expect(ok, isTrue);
    expect(publishCalls, 2);
    expect(burnPromptCalls, 1);
    expect(c.draft.value.status, 'published');
    verify(
      () => shifts.publishShift(
        'shift-1',
        body: any(
          named: 'body',
          that: isA<ShiftPublishRequest>().having(
            (b) => b.budgetOverrideReason,
            'budgetOverrideReason',
            'SC confirmed statement remaining',
          ),
        ),
      ),
    ).called(1);
  });

  test('budget override requires billing.manage', () async {
    when(() => session.hasPermission(AppPermissions.billingManage))
        .thenReturn(false);
    when(() => session.hasPermission(AppPermissions.shiftsManage))
        .thenReturn(true);
    when(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).thenThrow(
      const AppFailure(
        code: 'budget_burn_blocked',
        message: 'Publishing would exceed plan budget thresholds.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    var burnPromptCalls = 0;
    final c = await readyComposer(
      promptBurnOverride: ({required List<String> reasons}) async {
        burnPromptCalls++;
        return 'should-not-run';
      },
    );

    final ok = await c.publish();

    expect(ok, isFalse);
    expect(burnPromptCalls, 0);
    verify(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).called(1);
  });

  test('credential_gate_blocked on publish prompts then republishes', () async {
    var publishCalls = 0;
    var credPromptCalls = 0;
    when(
      () => shifts.publishShift(any(), body: any(named: 'body')),
    ).thenAnswer((invocation) async {
      publishCalls++;
      final body = invocation.namedArguments[#body] as ShiftPublishRequest?;
      if (body?.overrideReason == null || body!.overrideReason!.isEmpty) {
        throw const AppFailure(
          code: 'credential_gate_blocked',
          message: 'Screening blocked',
          presentation: AppFailurePresentation.inline,
          eligibilityReasons: ['wwcc: expired'],
        );
      }
      return _publishedShift();
    });

    final c = await readyComposer(
      promptCredentialGateOverride:
          ({required List<String> reasons, required String title}) async {
            credPromptCalls++;
            expect(reasons, ['wwcc: expired']);
            return 'Director approved temporary cover';
          },
    );

    final ok = await c.publish();

    expect(ok, isTrue);
    expect(publishCalls, 2);
    expect(credPromptCalls, 1);
    expect(c.draft.value.status, 'published');
    verify(
      () => shifts.publishShift(
        'shift-1',
        body: any(
          named: 'body',
          that: isA<ShiftPublishRequest>().having(
            (b) => b.overrideReason,
            'overrideReason',
            'Director approved temporary cover',
          ),
        ),
      ),
    ).called(1);
  });

  test('assign credential gate during saveDraft prompts and retries', () async {
    var assignCalls = 0;
    when(
      () => shifts.assignShiftBatch(
        shiftId: any(named: 'shiftId'),
        contractorIds: any(named: 'contractorIds'),
        taskTemplate: any(named: 'taskTemplate'),
        overrideReason: any(named: 'overrideReason'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'credential_gate_blocked',
        message: 'Screening blocked',
        presentation: AppFailurePresentation.inline,
        eligibilityReasons: ['police_check: missing'],
      ),
    );
    when(
      () => shifts.assignShift(
        shiftId: any(named: 'shiftId'),
        contractorId: any(named: 'contractorId'),
        taskTemplate: any(named: 'taskTemplate'),
        overrideReason: any(named: 'overrideReason'),
      ),
    ).thenAnswer((invocation) async {
      assignCalls++;
      final reason = invocation.namedArguments[#overrideReason] as String?;
      if (reason == null || reason.isEmpty) {
        throw const AppFailure(
          code: 'credential_gate_blocked',
          message: 'Screening blocked',
          presentation: AppFailurePresentation.inline,
          eligibilityReasons: ['police_check: missing'],
        );
      }
      return ShiftOut(
        id: 'shift-1',
        tenantId: 't1',
        jobId: 'job-1',
        jobTitle: 'Support',
        clientId: 'c1',
        scheduledStart: DateTime.utc(2026, 10, 4, 9),
        scheduledEnd: DateTime.utc(2026, 10, 4, 12),
        requiredSlots: 1,
        openSlots: 0,
        status: 'draft',
        assignments: const [
          ShiftAssignmentOut(
            id: 'a1',
            contractorId: 'w1',
            engagementId: 'e1',
            contractorName: 'Worker',
            visitId: 'v1',
            source: 'staff',
            status: 'active',
          ),
        ],
        createdAt: DateTime.utc(2026, 10, 4),
        updatedAt: DateTime.utc(2026, 10, 4),
      );
    });

    final c = await readyComposer(
      promptCredentialGateOverride:
          ({required List<String> reasons, required String title}) async {
            return 'Manager approved missing check';
          },
    );
    c.draft.value = c.draft.value.copyWith(contractorIds: ['w1']);

    final ok = await c.saveDraft();

    expect(ok, isTrue);
    expect(assignCalls, 2);
    expect(c.assignOverrideReasons['w1'], 'Manager approved missing check');
    expect(c.credentialGateReasons, ['police_check: missing']);
  });
}
