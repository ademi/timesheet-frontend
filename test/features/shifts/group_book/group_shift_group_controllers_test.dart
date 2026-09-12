import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/jobs/data/models/job_models.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_book_args.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_book_controller.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_edit_controller.dart';
import 'package:rostiq/features/shifts/group_book/group_shift_remove_controller.dart';
import 'package:rostiq/features/shifts/utils/group_participant_draft.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _FakeShiftCreateRequest extends Fake implements ShiftCreateRequest {}

class _FakeShiftParticipantsReplaceRequest extends Fake
    implements ShiftParticipantsReplaceRequest {}

final _now = DateTime.utc(2026, 9, 12, 9);

ClientOut _client(String id, String name) => ClientOut(
  id: id,
  tenantId: 'tenant-1',
  fullName: name,
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

final _host = _client('host-1', 'Host House');
final _maya = _client('c-maya', 'Maya Smith');
final _jordan = _client('c-jordan', 'Jordan Lee');

final _job = JobOut(
  id: 'job-1',
  tenantId: 'tenant-1',
  kind: 'standing',
  status: 'open',
  title: 'Host House support',
  geofenceRadiusM: 100,
  geofenceMode: 'informational',
  createdAt: _now,
  updatedAt: _now,
  clientId: 'host-1',
);

ShiftOut _shift({
  String status = 'draft',
  List<ShiftParticipantOut> participants = const [],
  int workerCount = 1,
}) {
  return ShiftOut(
    id: 'shift-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Host House support',
    clientId: 'host-1',
    clientName: 'Host House',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 3)),
    requiredSlots: 1,
    openSlots: 1,
    workerCount: workerCount,
    status: status,
    participants: participants,
    createdAt: _now,
    updatedAt: _now,
  );
}

ShiftParticipantOut _participant({
  required String id,
  required String participantId,
  required String name,
  double? allocationValue = 50,
  String status = 'active',
  String allocationStrategy = 'percentage',
  List<ShiftParticipantAllocationOut>? timeWindows,
}) {
  return ShiftParticipantOut(
    id: id,
    participantId: participantId,
    participantName: name,
    status: status,
    allocationStrategy: allocationStrategy,
    allocationValue: allocationValue,
    timeWindows: timeWindows,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeShiftCreateRequest());
    registerFallbackValue(_FakeShiftParticipantsReplaceRequest());
  });

  group('GroupShiftBookController', () {
    late _MockClientsRepository clients;
    late _MockJobsRepository jobs;
    late _MockShiftsRepository shifts;
    late _MockSessionService session;
    late List<({String route, dynamic arguments})> navigations;
    late List<int> largeGroupPrompts;

    GroupShiftBookController build({GroupShiftBookArgs? args}) {
      final c = GroupShiftBookController(
        clientsRepository: clients,
        jobsRepository: jobs,
        shiftsRepository: shifts,
        session: session,
        args: args,
        onNavigate: (route, arguments) {
          navigations.add((route: route, arguments: arguments));
        },
        confirmLargeGroup: (nextN) async {
          largeGroupPrompts.add(nextN);
          return true;
        },
      );
      c.onInit();
      return c;
    }

    setUp(() {
      Get.testMode = true;
      clients = _MockClientsRepository();
      jobs = _MockJobsRepository();
      shifts = _MockShiftsRepository();
      session = _MockSessionService();
      navigations = [];
      largeGroupPrompts = [];
      when(() => session.hasPermission(any())).thenReturn(true);
      when(() => session.tenantId).thenReturn(RxnString());
      when(() => session.tenantTimezone).thenReturn(RxnString('UTC'));
      when(() => clients.listClients()).thenAnswer(
        (_) async => [_host, _maya, _jordan],
      );
    });

    tearDown(Get.reset);

    test('Remaining blocks Next when Capacity % does not sum to 100', () async {
      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      await c.addParticipant(_maya);
      await c.addParticipant(_jordan);
      c.setEqualSplit(false);
      c.setAllocation('c-maya', 40);
      c.setAllocation('c-jordan', 40);

      expect(c.canGoNext(), isFalse);
      expect(c.errorMessage.value, contains('Remaining'));
      expect(c.step.value, 0);

      c.setAllocation('c-maya', 60);
      expect(c.canGoNext(), isTrue);
    });

    test('large-group confirm prompted when adding would make N >= 9', () async {
      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      for (var i = 0; i < 8; i++) {
        await c.addParticipant(_client('c$i', 'Person $i'));
      }
      expect(c.draft.value.length, 8);
      expect(largeGroupPrompts, isEmpty);

      final ok = await c.addParticipant(_client('c8', 'Person 8'));
      expect(ok, isTrue);
      expect(largeGroupPrompts, [9]);
      expect(c.draft.value.length, 9);
    });

    test('D11 prefill adds participant only; host stays empty', () async {
      final c = build(
        args: GroupShiftBookArgs(
          participantId: _maya.id,
          participantName: _maya.fullName,
        ),
      );
      await c._waitBootstrap();
      expect(c.host.value, isNull);
      expect(c.includeHost.value, isFalse);
      expect(c.draft.value.participants.map((p) => p.participantId), [_maya.id]);
    });

    test('createDraft one createShift then navigates detail', () async {
      when(() => jobs.ensureOngoingSupport('host-1')).thenAnswer((_) async => _job);
      when(() => shifts.createShift(any())).thenAnswer(
        (_) async => _shift(
          participants: [
            _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName, allocationValue: 100),
          ],
        ),
      );

      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      await c.addParticipant(_maya);
      c.step.value = GroupShiftBookController.reviewStep;
      await c.createDraft();

      verify(() => shifts.createShift(any())).called(1);
      expect(navigations, hasLength(1));
      expect(navigations.single.route, AppRoutes.staffShiftDetail);
      expect(c.isSaving.value, isFalse);
    });

    test('createDraft error toast path keeps Review and clears busy', () async {
      when(() => jobs.ensureOngoingSupport('host-1')).thenAnswer((_) async => _job);
      when(() => shifts.createShift(any())).thenThrow(
        const AppFailure(
          code: 'validation_error',
          message: 'participants_sum_invalid',
          presentation: AppFailurePresentation.toast,
        ),
      );

      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      await c.addParticipant(_maya);
      c.step.value = GroupShiftBookController.reviewStep;
      await c.createDraft();

      expect(c.isSaving.value, isFalse);
      expect(c.errorMessage.value, 'participants_sum_invalid');
      expect(navigations, isEmpty);
    });

    test('createDraft ignores second call while busy', () async {
      when(() => jobs.ensureOngoingSupport('host-1')).thenAnswer((_) async => _job);
      when(() => shifts.createShift(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return _shift();
      });

      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      await c.addParticipant(_maya);
      c.step.value = GroupShiftBookController.reviewStep;
      final first = c.createDraft();
      final second = c.createDraft();
      await Future.wait([first, second]);
      verify(() => shifts.createShift(any())).called(1);
    });

    test('createDraft time_based includes time_windows', () async {
      when(() => jobs.ensureOngoingSupport('host-1')).thenAnswer((_) async => _job);
      when(() => shifts.createShift(any())).thenAnswer((_) async => _shift());

      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      await c.addParticipant(_maya);
      c.setAllocationStrategy(GroupAllocationStrategy.timeBased);
      expect(c.draft.value.isTimeBased, isTrue);
      expect(c.draft.value.participants.single.timeWindows, isNotEmpty);

      c.step.value = GroupShiftBookController.reviewStep;
      await c.createDraft();

      final captured = verify(() => shifts.createShift(captureAny())).captured.single
          as ShiftCreateRequest;
      expect(captured.equalSplit, isFalse);
      expect(captured.participants, hasLength(1));
      final item = captured.participants.single;
      expect(item.allocationStrategy, 'time_based');
      expect(item.allocationValue, 0);
      expect(item.timeWindows, isNotNull);
      expect(item.timeWindows, isNotEmpty);
    });

    test('time_based windows realign when When schedule changes', () async {
      final c = build();
      await c._waitBootstrap();
      c.selectHost(_host);
      await c.addParticipant(_maya);
      c.setAllocationStrategy(GroupAllocationStrategy.timeBased);

      final originalEnd = c.scheduledEnd.value;
      final earlierEnd = c.scheduledStart.value.add(const Duration(hours: 1));
      expect(originalEnd.isAfter(earlierEnd), isTrue);

      c.scheduledEnd.value = earlierEnd;

      final win = c.draft.value.participants.single.timeWindows.single;
      expect(win.start, c.scheduledStart.value);
      expect(win.end, earlierEnd);
    });
  });

  group('GroupShiftEditController', () {
    late _MockShiftsRepository shifts;

    setUp(() {
      Get.testMode = true;
      shifts = _MockShiftsRepository();
    });

    tearDown(Get.reset);

    test('Save busy disables double-submit', () async {
      when(() => shifts.putParticipants(any(), any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return _shift();
      });

      final c = GroupShiftEditController(
        shiftsRepository: shifts,
        args: GroupShiftEditArgs(
          shift: _shift(
            participants: [
              _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName, allocationValue: 100),
            ],
          ),
        ),
        onSaved: (_) {},
      );
      c.onInit();

      final first = c.save();
      final second = c.save();
      await Future.wait([first, second]);
      verify(() => shifts.putParticipants(any(), any())).called(1);
      expect(c.isSaving.value, isFalse);
    });

    test('Save error toast path keeps draft and clears busy', () async {
      when(() => shifts.putParticipants(any(), any())).thenThrow(
        const AppFailure(
          code: 'conflict',
          message: 'shift_not_draft',
          presentation: AppFailurePresentation.toast,
          statusCode: 409,
        ),
      );

      final c = GroupShiftEditController(
        shiftsRepository: shifts,
        args: GroupShiftEditArgs(
          shift: _shift(
            participants: [
              _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName, allocationValue: 100),
            ],
          ),
        ),
        onSaved: (_) {},
      );
      c.onInit();
      await c.save();

      expect(c.isSaving.value, isFalse);
      expect(c.errorMessage.value, 'shift_not_draft');
      expect(c.draft.value.length, 1);
    });

    test('Save builds time_based PUT body', () async {
      when(() => shifts.putParticipants(any(), any())).thenAnswer(
        (_) async => _shift(),
      );

      final c = GroupShiftEditController(
        shiftsRepository: shifts,
        args: GroupShiftEditArgs(
          shift: _shift(
            participants: [
              _participant(
                id: 'sp1',
                participantId: _maya.id,
                name: _maya.fullName,
                allocationValue: 100,
              ),
            ],
          ),
        ),
        onSaved: (_) {},
      );
      c.onInit();
      c.setAllocationStrategy(GroupAllocationStrategy.timeBased);
      await c.save();

      final body =
          verify(
                () => shifts.putParticipants('shift-1', captureAny()),
              ).captured.single
              as ShiftParticipantsReplaceRequest;
      expect(body.allocationStrategy, 'time_based');
      expect(body.equalSplit, isFalse);
      expect(body.participants, hasLength(1));
      expect(body.participants.single.allocationValue, 0);
      expect(body.participants.single.timeWindows, isNotNull);
      expect(body.participants.single.timeWindows, isNotEmpty);
    });

    test('Save time_based windows use tenant civil timezone', () async {
      when(() => shifts.putParticipants(any(), any())).thenAnswer(
        (_) async => _shift(),
      );

      final c = GroupShiftEditController(
        shiftsRepository: shifts,
        args: GroupShiftEditArgs(
          shift: _shift(
            participants: [
              _participant(
                id: 'sp1',
                participantId: _maya.id,
                name: _maya.fullName,
                allocationValue: 100,
              ),
            ],
          ),
        ),
        onSaved: (_) {},
        resolveTenantTimezone: () async => 'Pacific/Honolulu',
      );
      c.onInit();
      c.setAllocationStrategy(GroupAllocationStrategy.timeBased);
      final draftWin = c.draft.value.participants.single.timeWindows.single;
      await c.save();

      final body =
          verify(
                () => shifts.putParticipants('shift-1', captureAny()),
              ).captured.single
              as ShiftParticipantsReplaceRequest;
      final win = body.participants.single.timeWindows!.single;
      expect(
        win.participantStartTime,
        tenantCivilInstantUtc(draftWin.start, 'Pacific/Honolulu'),
      );
      expect(
        win.participantEndTime,
        tenantCivilInstantUtc(draftWin.end, 'Pacific/Honolulu'),
      );
    });

    test('strategy switch hydrates default full-shift windows', () {
      final c = GroupShiftEditController(
        shiftsRepository: shifts,
        args: GroupShiftEditArgs(
          shift: _shift(
            participants: [
              _participant(
                id: 'sp1',
                participantId: _maya.id,
                name: _maya.fullName,
                allocationValue: 100,
              ),
            ],
          ),
        ),
        onSaved: (_) {},
      );
      c.onInit();
      expect(c.draft.value.isTimeBased, isFalse);
      c.setAllocationStrategy(GroupAllocationStrategy.timeBased);
      expect(c.draft.value.isTimeBased, isTrue);
      final win = c.draft.value.participants.single.timeWindows.single;
      expect(win.start, c.shiftStart);
      expect(win.end, c.shiftEnd);
    });

    test('hydrates time_based participants from shift detail', () {
      final start = _now;
      final end = _now.add(const Duration(hours: 3));
      final c = GroupShiftEditController(
        shiftsRepository: shifts,
        args: GroupShiftEditArgs(
          shift: _shift(
            participants: [
              _participant(
                id: 'sp1',
                participantId: _maya.id,
                name: _maya.fullName,
                allocationValue: 0,
                allocationStrategy: 'time_based',
                timeWindows: [
                  ShiftParticipantAllocationOut(
                    id: 'tw1',
                    shiftParticipantId: 'sp1',
                    participantStartTime: start,
                    participantEndTime: end,
                    createdAt: _now,
                  ),
                ],
              ),
            ],
          ),
        ),
        onSaved: (_) {},
      );
      c.onInit();
      expect(c.draft.value.isTimeBased, isTrue);
      expect(c.draft.value.participants.single.timeWindows, hasLength(1));
    });
  });

  group('GroupShiftRemoveController', () {
    late _MockShiftsRepository shifts;

    setUp(() {
      Get.testMode = true;
      shifts = _MockShiftsRepository();
    });

    tearDown(Get.reset);

    test('empty reason blocked without DELETE', () async {
      final c = GroupShiftRemoveController(
        shiftsRepository: shifts,
        args: GroupShiftRemoveArgs(
          shift: _shift(
            status: 'published',
            participants: [
              _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName),
              _participant(id: 'sp2', participantId: _jordan.id, name: _jordan.fullName),
            ],
          ),
          participant: _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName),
        ),
        onRemoved: (_) {},
      );

      await c.remove();
      verifyNever(
        () => shifts.removeParticipant(
          any(),
          any(),
          reason: any(named: 'reason'),
          rebalance: any(named: 'rebalance'),
        ),
      );
      expect(c.errorMessage.value, 'Reason is required.');
    });

    test('Remove busy disables double-submit and uses equal rebalance', () async {
      when(
        () => shifts.removeParticipant(
          any(),
          any(),
          reason: any(named: 'reason'),
          rebalance: any(named: 'rebalance'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return _shift(status: 'published');
      });

      final c = GroupShiftRemoveController(
        shiftsRepository: shifts,
        args: GroupShiftRemoveArgs(
          shift: _shift(
            status: 'published',
            participants: [
              _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName),
              _participant(id: 'sp2', participantId: _jordan.id, name: _jordan.fullName),
            ],
          ),
          participant: _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName),
        ),
        onRemoved: (_) {},
      );
      c.reasonCtrl.text = 'No show';
      final first = c.remove();
      final second = c.remove();
      await Future.wait([first, second]);

      verify(
        () => shifts.removeParticipant(
          'shift-1',
          _maya.id,
          reason: 'No show',
          rebalance: 'equal',
        ),
      ).called(1);
      expect(c.isSaving.value, isFalse);
    });

    test('Remove uses rebalance none when time_based', () async {
      when(
        () => shifts.removeParticipant(
          any(),
          any(),
          reason: any(named: 'reason'),
          rebalance: any(named: 'rebalance'),
        ),
      ).thenAnswer((_) async => _shift(status: 'published'));

      final c = GroupShiftRemoveController(
        shiftsRepository: shifts,
        args: GroupShiftRemoveArgs(
          shift: _shift(
            status: 'published',
            participants: [
              _participant(
                id: 'sp1',
                participantId: _maya.id,
                name: _maya.fullName,
                allocationValue: 0,
                allocationStrategy: 'time_based',
              ),
              _participant(
                id: 'sp2',
                participantId: _jordan.id,
                name: _jordan.fullName,
                allocationValue: 0,
                allocationStrategy: 'time_based',
              ),
            ],
          ),
          participant: _participant(
            id: 'sp1',
            participantId: _maya.id,
            name: _maya.fullName,
            allocationValue: 0,
            allocationStrategy: 'time_based',
          ),
        ),
        onRemoved: (_) {},
      );
      expect(c.rebalanceMode, 'none');
      expect(c.rebalanceHint, contains('time windows'));
      c.reasonCtrl.text = 'Left early';
      await c.remove();

      verify(
        () => shifts.removeParticipant(
          'shift-1',
          _maya.id,
          reason: 'Left early',
          rebalance: 'none',
        ),
      ).called(1);
    });

    test('Remove error toast path clears busy', () async {
      when(
        () => shifts.removeParticipant(
          any(),
          any(),
          reason: any(named: 'reason'),
          rebalance: any(named: 'rebalance'),
        ),
      ).thenThrow(
        const AppFailure(
          code: 'network',
          message: 'offline',
          presentation: AppFailurePresentation.toast,
        ),
      );

      final c = GroupShiftRemoveController(
        shiftsRepository: shifts,
        args: GroupShiftRemoveArgs(
          shift: _shift(
            status: 'published',
            participants: [
              _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName),
            ],
          ),
          participant: _participant(id: 'sp1', participantId: _maya.id, name: _maya.fullName),
        ),
        onRemoved: (_) {},
      );
      c.reasonCtrl.text = 'Left early';
      await c.remove();
      expect(c.isSaving.value, isFalse);
      expect(c.errorMessage.value, 'offline');
    });
  });

  group('GroupParticipantDraftSet capacity helpers', () {
    test('withEqualSplit / setAllocation', () {
      var draft = GroupParticipantDraftSet(equalSplit: true)
          .add(
            const GroupParticipantDraft(
              participantId: 'c1',
              displayName: 'Maya',
              allocationValue: 0,
            ),
          )
          .add(
            const GroupParticipantDraft(
              participantId: 'c2',
              displayName: 'Jordan',
              allocationValue: 0,
            ),
          )
          .withEqualSplit(false)
          .setAllocation('c1', 70);

      expect(draft.equalSplit, isFalse);
      expect(draft.participants.map((p) => p.allocationValue), [70.0, 50.0]);
      expect(draft.remaining, -20.0);
    });
  });
}

extension on GroupShiftBookController {
  Future<void> _waitBootstrap() async {
    // onInit kicks _bootstrap; wait until loading settles.
    for (var i = 0; i < 40; i++) {
      if (!isLoading.value) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }
}
