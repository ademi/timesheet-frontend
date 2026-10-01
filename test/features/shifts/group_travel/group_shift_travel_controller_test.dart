import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
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

class _MockCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

final _now = DateTime.utc(2026, 9, 12, 9);

ShiftParticipantOut _participant(
  String id,
  String name, {
  String? supportItemCode,
}) {
  return ShiftParticipantOut(
    id: id,
    participantId: 'client-$id',
    participantName: name,
    status: 'active',
    rateSnapshot:
        supportItemCode == null
            ? null
            : ShiftParticipantRateSnapshotSummary(
              baseRate: 50,
              supportItemCode: supportItemCode,
            ),
  );
}

ShiftOut _shift({List<ShiftParticipantOut>? participants}) {
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
    participants:
        participants ??
        [_participant('sp-1', 'Maya'), _participant('sp-2', 'Lee')],
    createdAt: _now,
    updatedAt: _now,
  );
}

ShiftTravelOut _travel({
  String id = 'travel-1',
  String supportItemCode = '01_799_0107_1_1',
  double quantity = 10,
  TravelApportionmentMode mode = TravelApportionmentMode.equal,
  String? nominee,
}) {
  return ShiftTravelOut(
    id: id,
    shiftId: 'shift-1',
    supportItemCode: supportItemCode,
    quantity: quantity,
    apportionmentMode: mode,
    nominatedParticipantId: nominee,
    createdAt: _now,
    updatedAt: _now,
  );
}

void _completeDraft(GroupShiftTravelController controller) {
  controller.setItem(
    supportItemCode: '01_799_0107_1_1',
    supportItemName: 'Provider travel – non-labour',
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

  test('cancel pops null via onPop', () {
    dynamic popped = 'unset';
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift()),
      onPop: (result) => popped = result,
    );

    controller.cancel();

    expect(popped, isNull);
  });

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
    expect(body.claimKind, TravelClaimKind.nonLabour);
    expect(body.supportItemCode, '01_799_0107_1_1');
    expect(body.quantity, '10');
    expect(body.apportionmentMode, TravelApportionmentMode.equal);
  });

  test('labour save posts claim_kind and quantity_minutes', () async {
    final saved = ShiftTravelOut(
      id: 'travel-labour',
      shiftId: 'shift-1',
      claimKind: TravelClaimKind.labour,
      quantity: 0.75,
      apportionmentMode: TravelApportionmentMode.equal,
      mmmCategory: 1,
      mmmCapMinutes: 30,
      overCap: true,
      createdAt: _now,
      updatedAt: _now,
    );
    when(
      () => repository.createTravel('shift-1', any()),
    ).thenAnswer((_) async => saved);
    dynamic popped;
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift()),
      onPop: (result) => popped = result,
      mmmCategoryOverride: 1,
    );
    controller.setClaimKind(TravelClaimKind.labour);
    controller.setQuantity('45');

    expect(controller.showOverCapBanner, isTrue);

    await controller.save();

    expect(popped, same(saved));
    final body =
        verify(
              () => repository.createTravel('shift-1', captureAny()),
            ).captured.single
            as ShiftTravelWrite;
    expect(body.claimKind, TravelClaimKind.labour);
    expect(body.quantityMinutes, '45');
    expect(body.supportItemCode, isNull);
    expect(body.quantity, isNull);
    expect(body.toJson()['claim_kind'], 'labour');
    expect(body.toJson()['quantity_minutes'], '45');
    expect(body.toJson().containsKey('support_item_code'), isFalse);
  });

  test('labour edit prefills minutes from stored hours', () {
    final existing = ShiftTravelOut(
      id: 'travel-1',
      shiftId: 'shift-1',
      claimKind: TravelClaimKind.labour,
      quantity: 0.5,
      apportionmentMode: TravelApportionmentMode.nominated,
      nominatedParticipantId: 'sp-2',
      mmmCategory: 4,
      mmmCapMinutes: 60,
      overCap: false,
      createdAt: _now,
      updatedAt: _now,
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: _shift(), existing: existing),
    );

    expect(controller.draft.value.claimKind, TravelClaimKind.labour);
    expect(controller.draft.value.quantity, '30');
    expect(controller.mmmCategory.value, 4);
    expect(controller.canChangeClaimKind, isFalse);
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

  test('switching nominee clears mismatched travel item', () {
    final shift = _shift(
      participants: [
        _participant('sp-1', 'Maya', supportItemCode: '01_011_0107_1_1'),
        _participant('sp-2', 'Lee', supportItemCode: '04_104_0125_6_1'),
      ],
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: shift),
    );
    controller.setMode(TravelApportionmentMode.nominated);
    controller.setNominee('sp-1');
    controller.setItem(
      supportItemCode: '01_799_0107_1_1',
      supportItemName: 'Provider travel Maya group',
    );

    controller.setNominee('sp-2');

    expect(controller.draft.value.supportItemCode, isNull);
    expect(
      controller.itemClearedHelper.value,
      GroupShiftTravelController.itemClearedHelperMessage,
    );
  });

  test('equal mixed registration groups blocks next and save', () {
    final shift = _shift(
      participants: [
        _participant('sp-1', 'Maya', supportItemCode: '01_011_0107_1_1'),
        _participant('sp-2', 'Lee', supportItemCode: '04_104_0125_6_1'),
      ],
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: shift),
      onPop: (_) => fail('must not pop'),
    );
    _completeDraft(controller);
    controller.step.value = GroupShiftTravelController.splitStep;

    expect(controller.hasMixedEqualRegistrationGroups, isTrue);
    controller.nextStep();
    expect(
      controller.errorMessage.value,
      GroupShiftTravelController.mixedEqualErrorMessage,
    );
    expect(controller.step.value, GroupShiftTravelController.splitStep);
  });

  test('mixed equal on Item step still advances to Split', () {
    final shift = _shift(
      participants: [
        _participant('sp-1', 'Maya', supportItemCode: '01_011_0107_1_1'),
        _participant('sp-2', 'Lee', supportItemCode: '04_104_0125_6_1'),
      ],
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: shift),
    );

    expect(controller.hasMixedEqualRegistrationGroups, isTrue);
    expect(controller.step.value, GroupShiftTravelController.itemStep);
    controller.nextStep();
    expect(controller.step.value, GroupShiftTravelController.splitStep);
    expect(controller.errorMessage.value, isNull);
  });

  test('switchToNominatedSplit opens Split in nominated mode', () {
    final shift = _shift(
      participants: [
        _participant('sp-1', 'Maya', supportItemCode: '01_011_0107_1_1'),
        _participant('sp-2', 'Lee', supportItemCode: '04_104_0125_6_1'),
      ],
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: shift),
    );

    controller.switchToNominatedSplit();

    expect(
      controller.draft.value.apportionmentMode,
      TravelApportionmentMode.nominated,
    );
    expect(controller.step.value, GroupShiftTravelController.splitStep);
    expect(controller.hasMixedEqualRegistrationGroups, isFalse);
  });

  test('hydrateSupportItemName fills catalogue title for edit', () async {
    final catalogue = _MockCatalogueRepository();
    when(() => catalogue.fetchAllActiveItems()).thenAnswer(
      (_) async => [
        const NdisCatalogueItemOut(
          supportItemNumber: '01_799_0107_1_1',
          supportItemName: 'Provider travel - non-labour costs',
          unit: 'E',
        ),
      ],
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(
        shift: _shift(),
        existing: _travel(supportItemCode: '01_799_0107_1_1'),
      ),
      catalogueRepository: catalogue,
    );

    expect(controller.draft.value.supportItemName, isNull);
    await controller.hydrateSupportItemName();
    expect(
      controller.draft.value.supportItemName,
      'Provider travel - non-labour costs',
    );
  });

  test('travelCataloguePredicate keeps matching E mid-codes only', () {
    final shift = _shift(
      participants: [
        _participant('sp-1', 'Maya', supportItemCode: '01_011_0107_1_1'),
        _participant('sp-2', 'Lee', supportItemCode: '01_012_0107_1_1'),
      ],
    );
    final controller = GroupShiftTravelController(
      shiftsRepository: repository,
      args: GroupShiftTravelArgs(shift: shift),
    );

    expect(
      controller.travelCataloguePredicate(
        const NdisCatalogueItemOut(
          supportItemNumber: '01_799_0107_1_1',
          supportItemName: 'Provider travel',
          unit: 'E',
        ),
      ),
      isTrue,
    );
    expect(
      controller.travelCataloguePredicate(
        const NdisCatalogueItemOut(
          supportItemNumber: '04_799_0125_6_1',
          supportItemName: 'Wrong group travel',
          unit: 'E',
        ),
      ),
      isFalse,
    );
    expect(
      controller.travelCataloguePredicate(
        const NdisCatalogueItemOut(
          supportItemNumber: '01_011_0107_1_1',
          supportItemName: 'Self care',
          unit: 'H',
        ),
      ),
      isFalse,
    );
  });
}
