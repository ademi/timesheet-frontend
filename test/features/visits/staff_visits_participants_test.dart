import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
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

class _FakeParticipantBatchRequest extends Fake
    implements ShiftParticipantBatchCreateRequest {}

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
    registerFallbackValue(_FakeParticipantBatchRequest());
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

  testWidgets('keeps draft and error when empty participants batch fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SizedBox.shrink()),
          GetPage(
            name: AppRoutes.staffShiftDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    final draft = _shift();
    when(
      () => jobs.ensureOngoingSupport('host-1'),
    ).thenAnswer((_) async => _support());
    when(() => shifts.createShift(any())).thenAnswer((_) async => draft);
    when(
      () => shifts.addParticipantsBatch(
        shiftId: draft.id,
        body: any(named: 'body'),
      ),
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
      participants: const [],
    );
    await tester.pumpAndSettle();

    expect(ok, isFalse);
    expect(controller.errorMessage.value, 'Could not add participant.');
    expect(controller.selectedShift.value?.id, draft.id);
    expect(controller.selectedShift.value?.participants, isEmpty);
    expect(controller.showDraftCapacityHint.value, isTrue);
    final arguments = Get.arguments as Map;
    expect(arguments['shift'], same(draft));
    expect(arguments['errorMessage'], 'Could not add participant.');
    expect(arguments['showDraftCapacityHint'], isTrue);
    final batch =
        verify(
              () => shifts.addParticipantsBatch(
                shiftId: draft.id,
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as ShiftParticipantBatchCreateRequest;
    expect(batch.participants, isEmpty);
    verifyNever(
      () => shifts.addParticipant(
        shiftId: any(named: 'shiftId'),
        body: any(named: 'body'),
      ),
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
    verifyNever(
      () => shifts.addParticipantsBatch(
        shiftId: any(named: 'shiftId'),
        body: any(named: 'body'),
      ),
    );
  });

  test('double booking guard allows only one create and batch', () async {
    final createCompleter = Completer<ShiftOut>();
    final draft = _shift();
    final complete = _shift(participants: [_participant('host-1', 100)]);
    when(
      () => jobs.ensureOngoingSupport('host-1'),
    ).thenAnswer((_) async => _support());
    when(
      () => shifts.createShift(any()),
    ).thenAnswer((_) => createCompleter.future);
    when(
      () => shifts.addParticipantsBatch(
        shiftId: draft.id,
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => complete,
    );

    final first = controller.bookGroupShift(
      hostClientId: 'host-1',
      start: _now,
      end: _now.add(const Duration(hours: 2)),
      participants: [_request('host-1', 100)],
    );
    final second = await controller.bookGroupShift(
      hostClientId: 'host-1',
      start: _now,
      end: _now.add(const Duration(hours: 2)),
      participants: [_request('host-1', 100)],
    );

    expect(second, isFalse);
    verify(() => jobs.ensureOngoingSupport('host-1')).called(1);

    createCompleter.complete(draft);
    expect(await first, isTrue);
    verify(() => shifts.createShift(any())).called(1);
    verify(
      () => shifts.addParticipantsBatch(
        shiftId: draft.id,
        body: any(named: 'body'),
      ),
    ).called(1);
    verifyNever(
      () => shifts.addParticipant(
        shiftId: any(named: 'shiftId'),
        body: any(named: 'body'),
      ),
    );
  });

  testWidgets('creates draft and adds every participant in one batch', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SizedBox.shrink()),
          GetPage(
            name: AppRoutes.staffShiftDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
    final draft = _shift();
    final complete = _shift(
      participants: [_participant('host-1', 60), _participant('guest-1', 40)],
    );
    final requests = [_request('host-1', 60), _request('guest-1', 40)];
    when(
      () => jobs.ensureOngoingSupport('host-1'),
    ).thenAnswer((_) async => _support());
    when(() => shifts.createShift(any())).thenAnswer((_) async => draft);
    when(
      () => shifts.addParticipantsBatch(
        shiftId: draft.id,
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => complete);

    final ok = await controller.bookGroupShift(
      hostClientId: 'host-1',
      start: _now,
      end: _now.add(const Duration(hours: 2)),
      participants: requests,
      requiredSlots: 2,
    );
    await tester.pumpAndSettle();

    expect(ok, isTrue);
    final createRequest =
        verify(() => shifts.createShift(captureAny())).captured.single
            as ShiftCreateRequest;
    expect(createRequest.status, 'draft');
    expect(createRequest.requiredSlots, 2);
    final batch =
        verify(
          () => shifts.addParticipantsBatch(
            shiftId: draft.id,
            body: captureAny(named: 'body'),
          ),
        ).captured.single as ShiftParticipantBatchCreateRequest;
    expect(batch.participants.map((request) => request.participantId), [
      'host-1',
      'guest-1',
    ]);
    verifyNever(
      () => shifts.addParticipant(
        shiftId: any(named: 'shiftId'),
        body: any(named: 'body'),
      ),
    );
    expect(controller.selectedShift.value?.participants, hasLength(2));
    expect(controller.showDraftCapacityHint.value, isFalse);
    final arguments = Get.arguments as Map;
    expect(arguments['shift'], same(complete));
    expect(arguments.containsKey('errorMessage'), isFalse);
    expect(arguments['showDraftCapacityHint'], isFalse);
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

  test('replaces time-based participant to persist edited windows', () async {
    final participant = ShiftParticipantOut(
      id: 'shift-participant-host-1',
      shiftId: 'shift-1',
      participantId: 'host-1',
      allocationStrategy: 'time_based',
      allocationValue: 0,
      status: 'active',
      timeWindows: const [],
      createdAt: _now,
      updatedAt: _now,
    );
    final original = _shift(participants: [participant]);
    final removed = _shift();
    final replacement = ShiftParticipantCreateRequest(
      participantId: 'host-1',
      allocationStrategy: 'time_based',
      allocationValue: 0,
      reason: 'Correct attendance window',
      timeWindows: [
        ShiftParticipantAllocationWindow(
          participantStartTime: _now,
          participantEndTime: _now.add(const Duration(hours: 1)),
        ),
      ],
    );
    final updated = _shift(
      participants: [
        participant.copyWith(
          timeWindows: [
            ShiftParticipantAllocationOut(
              id: 'window-1',
              shiftParticipantId: participant.id,
              participantStartTime: _now,
              participantEndTime: _now.add(const Duration(hours: 1)),
              createdAt: _now,
            ),
          ],
        ),
      ],
    );
    controller.selectedShift.value = original;
    when(
      () => shifts.removeParticipant(
        shiftId: original.id,
        participantId: participant.participantId,
        reason: replacement.reason,
      ),
    ).thenAnswer((_) async => removed);
    when(
      () => shifts.addParticipant(shiftId: original.id, body: replacement),
    ).thenAnswer((_) async => updated);

    await controller.replaceTimeBasedParticipantOnSelected(
      participant: participant,
      replacement: replacement,
    );

    expect(controller.selectedShift.value, same(updated));
    verifyInOrder([
      () => shifts.removeParticipant(
        shiftId: original.id,
        participantId: participant.participantId,
        reason: replacement.reason,
      ),
      () => shifts.addParticipant(shiftId: original.id, body: replacement),
    ]);
  });

  test(
    'restores original time-based participant when replacement add fails',
    () async {
      final window = ShiftParticipantAllocationOut(
        id: 'window-1',
        shiftParticipantId: 'shift-participant-host-1',
        participantStartTime: _now,
        participantEndTime: _now.add(const Duration(hours: 1)),
        createdAt: _now,
      );
      final participant = ShiftParticipantOut(
        id: 'shift-participant-host-1',
        shiftId: 'shift-1',
        participantId: 'host-1',
        allocationStrategy: 'time_based',
        allocationValue: 0,
        status: 'active',
        timeWindows: [window],
        createdAt: _now,
        updatedAt: _now,
      );
      final original = _shift(participants: [participant]);
      final removed = _shift();
      final restored = _shift(participants: [participant]);
      final replacement = ShiftParticipantCreateRequest(
        participantId: 'host-1',
        allocationStrategy: 'time_based',
        allocationValue: 0,
        reason: 'Bad window edit',
        timeWindows: [
          ShiftParticipantAllocationWindow(
            participantStartTime: _now.add(const Duration(minutes: 30)),
            participantEndTime: _now.add(const Duration(hours: 2)),
          ),
        ],
      );
      controller.selectedShift.value = original;
      when(
        () => shifts.removeParticipant(
          shiftId: original.id,
          participantId: participant.participantId,
          reason: replacement.reason,
        ),
      ).thenAnswer((_) async => removed);
      when(
        () => shifts.addParticipant(shiftId: original.id, body: any(named: 'body')),
      ).thenAnswer((invocation) async {
        final body =
            invocation.namedArguments[#body] as ShiftParticipantCreateRequest;
        if (body.reason == replacement.reason) {
          throw const AppFailure(
            code: 'time_windows_required',
            message: 'Time-based participants need at least one time window.',
            presentation: AppFailurePresentation.inline,
          );
        }
        return restored;
      });

      await controller.replaceTimeBasedParticipantOnSelected(
        participant: participant,
        replacement: replacement,
      );

      expect(controller.selectedShift.value, same(restored));
      expect(
        controller.errorMessage.value,
        'Time-based participants need at least one time window.',
      );
      final added =
          verify(
            () => shifts.addParticipant(
              shiftId: original.id,
              body: captureAny(named: 'body'),
            ),
          ).captured.cast<ShiftParticipantCreateRequest>();
      expect(added, hasLength(2));
      expect(added.first.reason, replacement.reason);
      expect(added.last.participantId, 'host-1');
      expect(added.last.allocationStrategy, 'time_based');
      expect(added.last.timeWindows, hasLength(1));
      expect(added.last.timeWindows!.first.participantStartTime, _now);
    },
  );
}
