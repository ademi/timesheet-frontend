import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_participant_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeShiftCreateRequest extends Fake implements ShiftCreateRequest {}

class _FakeParticipantRequest extends Fake
    implements ShiftParticipantCreateRequest {}

final _now = DateTime.utc(2026, 9, 10, 9);

JobOut _support() => JobOut(
  id: 'support-1',
  tenantId: 'tenant-1',
  clientId: 'host-1',
  kind: 'standing',
  status: 'open',
  title: 'Ongoing support',
  geofenceRadiusM: 100,
  geofenceMode: 'informational',
  createdAt: _now,
  updatedAt: _now,
);

ShiftParticipantOut _participant(String id, double allocation) =>
    ShiftParticipantOut(
      id: 'shift-participant-$id',
      shiftId: 'shift-1',
      participantId: id,
      allocationStrategy: 'percentage',
      allocationValue: allocation,
      status: 'active',
      createdAt: _now,
      updatedAt: _now,
    );

ShiftOut _shift({
  List<ShiftParticipantOut> participants = const [],
  String status = 'draft',
}) => ShiftOut(
  id: 'shift-1',
  tenantId: 'tenant-1',
  jobId: 'support-1',
  jobTitle: 'Ongoing support',
  clientId: 'host-1',
  clientName: 'Host Client',
  scheduledStart: _now,
  scheduledEnd: _now.add(const Duration(hours: 2)),
  requiredSlots: 1,
  openSlots: 1,
  status: status,
  participants: participants,
  createdAt: _now,
  updatedAt: _now,
);

ShiftParticipantCreateRequest _request(String id, double allocation) =>
    ShiftParticipantCreateRequest(
      participantId: id,
      allocationStrategy: 'percentage',
      allocationValue: allocation,
      reason: 'group booking',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockJobsRepository jobs;
  late _MockEngagementsRepository engagements;
  late _MockSessionService session;
  late StaffVisitsController controller;

  setUpAll(() {
    registerFallbackValue(_FakeShiftCreateRequest());
    registerFallbackValue(_FakeParticipantRequest());
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    jobs = _MockJobsRepository();
    engagements = _MockEngagementsRepository();
    session = _MockSessionService();

    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => session.tenantId).thenReturn(RxnString());
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
    when(() => engagements.listTenantEngagements()).thenAnswer((_) async => []);

    controller = StaffVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      jobsRepository: jobs,
      engagementsRepository: engagements,
      session: session,
    );
  });

  tearDown(Get.reset);

  test('keeps draft and error when second participant add fails', () async {
    final draft = _shift();
    final afterFirst = _shift(participants: [_participant('host-1', 60)]);
    final requests = [
      _request('host-1', 60),
      _request('guest-1', 30),
      _request('guest-2', 10),
    ];
    when(
      () => jobs.ensureOngoingSupport('host-1'),
    ).thenAnswer((_) async => _support());
    when(() => shifts.createShift(any())).thenAnswer((_) async => draft);
    when(
      () => shifts.addParticipant(shiftId: draft.id, body: requests.first),
    ).thenAnswer((_) async => afterFirst);
    when(
      () => shifts.addParticipant(shiftId: draft.id, body: requests[1]),
    ).thenThrow(
      const AppFailure(
        code: 'allocation_exceeds_100',
        message: 'Could not add participant.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    final ok = await controller.bookGroupShift(
      hostClientId: 'host-1',
      start: _now,
      end: _now.add(const Duration(hours: 2)),
      participants: requests,
    );

    expect(ok, isFalse);
    expect(controller.errorMessage.value, 'Could not add participant.');
    expect(controller.selectedShift.value?.id, draft.id);
    expect(controller.selectedShift.value?.participants, hasLength(1));
    expect(controller.showDraftCapacityHint.value, isTrue);
    verify(
      () => shifts.addParticipant(shiftId: draft.id, body: any(named: 'body')),
    ).called(2);
    verifyNever(
      () => shifts.addParticipant(shiftId: draft.id, body: requests.last),
    );
  });

  test('create failure stays put and preserves selected shift', () async {
    final previous = _shift(status: 'published');
    controller.selectedShift.value = previous;
    when(
      () => jobs.ensureOngoingSupport('host-1'),
    ).thenAnswer((_) async => _support());
    when(() => shifts.createShift(any())).thenThrow(
      const AppFailure(
        code: 'shift_overlap',
        message: 'Shift overlaps.',
        presentation: AppFailurePresentation.inline,
      ),
    );

    final ok = await controller.bookGroupShift(
      hostClientId: 'host-1',
      start: _now,
      end: _now.add(const Duration(hours: 2)),
      participants: [_request('host-1', 100)],
    );

    expect(ok, isFalse);
    expect(controller.errorMessage.value, 'Shift overlaps.');
    expect(controller.selectedShift.value, same(previous));
    expect(Get.arguments, isNull);
    verifyNever(
      () => shifts.addParticipant(
        shiftId: any(named: 'shiftId'),
        body: any(named: 'body'),
      ),
    );
  });

  test('creates draft and adds every participant sequentially', () async {
    final draft = _shift();
    final first = _shift(participants: [_participant('host-1', 60)]);
    final complete = _shift(
      participants: [_participant('host-1', 60), _participant('guest-1', 40)],
    );
    final requests = [_request('host-1', 60), _request('guest-1', 40)];
    when(
      () => jobs.ensureOngoingSupport('host-1'),
    ).thenAnswer((_) async => _support());
    when(() => shifts.createShift(any())).thenAnswer((_) async => draft);
    var addIndex = 0;
    when(
      () => shifts.addParticipant(shiftId: draft.id, body: any(named: 'body')),
    ).thenAnswer((_) async => addIndex++ == 0 ? first : complete);

    final ok = await controller.bookGroupShift(
      hostClientId: 'host-1',
      start: _now,
      end: _now.add(const Duration(hours: 2)),
      participants: requests,
      requiredSlots: 2,
    );

    expect(ok, isTrue);
    final createRequest =
        verify(() => shifts.createShift(captureAny())).captured.single
            as ShiftCreateRequest;
    expect(createRequest.status, 'draft');
    expect(createRequest.requiredSlots, 2);
    final added =
        verify(
          () => shifts.addParticipant(
            shiftId: draft.id,
            body: captureAny(named: 'body'),
          ),
        ).captured.cast<ShiftParticipantCreateRequest>();
    expect(added.map((request) => request.participantId), [
      'host-1',
      'guest-1',
    ]);
    expect(controller.selectedShift.value?.participants, hasLength(2));
    expect(controller.showDraftCapacityHint.value, isFalse);
  });

  test('canPublishSelected requires draft with ready allocation', () {
    controller.selectedShift.value = _shift(
      participants: [_participant('host-1', 60)],
    );
    expect(controller.canPublishSelected, isFalse);

    controller.selectedShift.value = _shift(
      participants: [_participant('host-1', 100)],
    );
    expect(controller.canPublishSelected, isTrue);

    controller.selectedShift.value = _shift(
      status: 'published',
      participants: [_participant('host-1', 100)],
    );
    expect(controller.canPublishSelected, isFalse);
  });
}
