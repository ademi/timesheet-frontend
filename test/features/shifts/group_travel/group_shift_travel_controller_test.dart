import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_travel_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/shifts/group_travel/group_shift_travel_args.dart';
import 'package:rostiq/features/shifts/group_travel/group_shift_travel_controller.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _FakeTravelWrite extends Fake implements ShiftTravelWrite {}

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 12, 9);

ShiftParticipantOut _participant(String id, String name) {
  return ShiftParticipantOut(
    id: id,
    participantId: 'client-$id',
    participantName: name,
    status: 'active',
  );
}

ShiftOut _shift() {
  return ShiftOut(
    id: 'shift-1',
    tenantId: 'tenant-1',
    jobId: 'job-1',
    jobTitle: 'Group support',
    scheduledStart: _now,
    scheduledEnd: _now.add(const Duration(hours: 2)),
    requiredSlots: 1,
    openSlots: 0,
    status: 'published',
    participants: [_participant('sp-1', 'Maya'), _participant('sp-2', 'Lee')],
    createdAt: _now,
    updatedAt: _now,
  );
}

ShiftTravelOut _travel({
  String id = 'travel-1',
  double quantity = 10,
  TravelApportionmentMode mode = TravelApportionmentMode.equal,
  String? nominee,
}) {
  return ShiftTravelOut(
    id: id,
    shiftId: 'shift-1',
    supportItemCode: '02_051_0108_1_1',
    quantity: quantity,
    apportionmentMode: mode,
    nominatedParticipantId: nominee,
    createdAt: _now,
    updatedAt: _now,
  );
}

void _completeDraft(GroupShiftTravelController controller) {
  controller.setItem(
    supportItemCode: '02_051_0108_1_1',
    supportItemName: 'Provider travel',
  );
  controller.setQuantity('10');
}

void main() {
  late _MockShiftsRepository repository;

  setUpAll(() {
    registerFallbackValue(_FakeTravelWrite());
  });

  setUp(() {
    Get.testMode = true;
    repository = _MockShiftsRepository();
  });

  tearDown(Get.reset);

  test('save create posts body and pops travel', () async {
    final saved = _travel();
    when(
      () => repository.createTravel('shift-1', any()),
    ).thenAnswer((_) async => saved);
    dynamic popped;
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift()),
      onPop: (result) => popped = result,
    );
    _completeDraft(controller);

    await controller.save();

    expect(popped, same(saved));
    final body =
        verify(
              () => repository.createTravel('shift-1', captureAny()),
            ).captured.single
            as ShiftTravelWrite;
    expect(body.supportItemCode, '02_051_0108_1_1');
    expect(body.quantity, '10');
    expect(body.apportionmentMode, TravelApportionmentMode.equal);
  });

  test('save edit prefills and patches existing travel', () async {
    final existing = _travel(
      quantity: 7.5,
      mode: TravelApportionmentMode.nominated,
      nominee: 'sp-2',
    );
    final saved = _travel(quantity: 8);
    when(
      () => repository.updateTravel('shift-1', 'travel-1', any()),
    ).thenAnswer((_) async => saved);
    dynamic popped;
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift(), existing: existing),
      onPop: (result) => popped = result,
    );

    expect(controller.draft.value.quantity, '7.5');
    expect(
      controller.draft.value.apportionmentMode,
      TravelApportionmentMode.nominated,
    );
    controller.setQuantity('8');
    await controller.save();

    expect(popped, same(saved));
    verify(
      () => repository.updateTravel('shift-1', 'travel-1', any()),
    ).called(1);
  });

  test('save error stays on Review and exposes message', () async {
    when(() => repository.createTravel('shift-1', any())).thenThrow(
      const AppFailure(
        code: 'travel_already_claimed',
        message: 'travel_already_claimed',
        presentation: AppFailurePresentation.toast,
        statusCode: 409,
      ),
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift()),
      onPop: (_) => fail('must not pop'),
    );
    _completeDraft(controller);
    controller.step.value = GroupShiftTravelController.reviewStep;

    await controller.save();

    expect(controller.step.value, GroupShiftTravelController.reviewStep);
    expect(controller.errorMessage.value, contains('Void'));
    expect(controller.isSaving.value, isFalse);
  });

  test('double save is ignored while request is busy', () async {
    final completer = Completer<ShiftTravelOut>();
    when(
      () => repository.createTravel('shift-1', any()),
    ).thenAnswer((_) => completer.future);
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift()),
      onPop: (_) {},
    );
    _completeDraft(controller);

    final first = controller.save();
    final second = controller.save();
    completer.complete(_travel());
    await Future.wait([first, second]);

    verify(() => repository.createTravel('shift-1', any())).called(1);
  });

  test('review shares use active shift participant row ids', () {
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift()),
    );
    _completeDraft(controller);

    expect(controller.apportionedQuantities, {'sp-1': 5, 'sp-2': 5});
    controller.setMode(TravelApportionmentMode.nominated);
    controller.setNominee('sp-2');
    expect(controller.apportionedQuantities, {'sp-2': 10});
  });

  test('selected shift travel helpers upsert and remove locally', () {
    final visitsController = StaffVisitsController(
      repository: _MockVisitsRepository(),
      shiftsRepository: repository,
      jobsRepository: _MockJobsRepository(),
      engagementsRepository: _MockEngagementsRepository(),
      clientsRepository: _MockClientsRepository(),
      session: _MockSessionService(),
    );
    visitsController.selectedShift.value = _shift();
    final first = _travel();
    final updated = _travel(quantity: 12);

    visitsController.upsertSelectedShiftTravel(first);
    visitsController.upsertSelectedShiftTravel(updated);

    expect(visitsController.selectedShift.value!.travelClaims, hasLength(1));
    expect(
      visitsController.selectedShift.value!.travelClaims.single.quantity,
      12,
    );

    visitsController.removeSelectedShiftTravel(first.id);
    expect(visitsController.selectedShift.value!.travelClaims, isEmpty);
  });
}
