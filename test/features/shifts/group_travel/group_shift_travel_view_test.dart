import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/billing/data/models/billing_models.dart';
import 'package:rostiq/features/billing/data/ndis_catalogue_filter_prefs.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/models/shift_travel_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/shifts/group_travel/group_shift_travel_args.dart';
import 'package:rostiq/features/shifts/group_travel/group_shift_travel_controller.dart';
import 'package:rostiq/features/shifts/group_travel/group_shift_travel_view.dart';

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

class _FakeTravelWrite extends Fake implements ShiftTravelWrite {}

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
        [
          _participant('sp-1', 'Maya', supportItemCode: '01_011_0107_1_1'),
          _participant('sp-2', 'Lee', supportItemCode: '04_104_0125_6_1'),
        ],
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockShiftsRepository shifts;
  late _MockNdisCatalogueRepository catalogue;
  late GroupShiftTravelController controller;
  late Map<String, dynamic> filterBox;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    shifts = _MockShiftsRepository();
    catalogue = _MockNdisCatalogueRepository();
    filterBox = <String, dynamic>{};
    when(
      () => catalogue.fetchAllActiveItems(),
    ).thenAnswer((_) async => const <NdisCatalogueItemOut>[]);
    Get.put<NdisCatalogueRepository>(catalogue);
  });

  setUpAll(() {
    registerFallbackValue(_FakeTravelWrite());
  });

  tearDown(Get.reset);

  NdisCatalogueFilterPrefs isolatedFilterPrefs() => NdisCatalogueFilterPrefs(
    read: (key) => filterBox[key],
    write: (key, value) => filterBox[key] = value,
    remove: (key) => filterBox.remove(key),
  );

  Future<void> pumpTravelView(
    WidgetTester tester, {
    required GroupShiftTravelController travelController,
  }) async {
    Get.put(travelController);
    await tester.pumpWidget(
      GetMaterialApp(
        home: GroupShiftTravelView(
          catalogueFilterPrefs: isolatedFilterPrefs(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('quantity field labelled Kilometres', (tester) async {
    controller = GroupShiftTravelController(
      shiftsRepository: shifts,
      args: GroupShiftTravelArgs(shift: _shift()),
    );
    await pumpTravelView(tester, travelController: controller);

    expect(find.text('Kilometres'), findsOneWidget);
    expect(find.text('Quantity'), findsNothing);
    expect(find.text('e.g. 12.5'), findsOneWidget);
  });

  testWidgets('switching nominee clears mismatched item and shows helper', (
    tester,
  ) async {
    controller = GroupShiftTravelController(
      shiftsRepository: shifts,
      args: GroupShiftTravelArgs(shift: _shift()),
    );
    controller.setMode(TravelApportionmentMode.nominated);
    controller.setNominee('sp-1');
    controller.setItem(
      supportItemCode: '01_799_0107_1_1',
      supportItemName: 'Provider travel Maya group',
    );
    controller.step.value = GroupShiftTravelController.splitStep;

    await pumpTravelView(tester, travelController: controller);

    expect(find.text('Lee'), findsOneWidget);
    await tester.tap(find.text('Lee'));
    await tester.pump();

    expect(controller.draft.value.supportItemCode, isNull);
    expect(
      find.textContaining('matches this participant'),
      findsOneWidget,
    );
  });

  testWidgets('shows no-anchors helper when snapshots are missing', (
    tester,
  ) async {
    final unpublished = _shift(
      participants: [_participant('sp-1', 'Maya'), _participant('sp-2', 'Lee')],
    );
    controller = GroupShiftTravelController(
      shiftsRepository: shifts,
      args: GroupShiftTravelArgs(shift: unpublished),
    );
    await pumpTravelView(tester, travelController: controller);

    expect(
      find.textContaining('Publish the shift to narrow'),
      findsOneWidget,
    );
  });

  testWidgets('Worker travel time section and Minutes label', (tester) async {
    controller = GroupShiftTravelController(
      shiftsRepository: shifts,
      args: GroupShiftTravelArgs(shift: _shift()),
    );
    await pumpTravelView(tester, travelController: controller);

    expect(find.text(GroupShiftTravelController.workerTimeSectionTitle), findsWidgets);
    await tester.tap(
      find.text(GroupShiftTravelController.workerTimeSectionTitle).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Minutes'), findsOneWidget);
    expect(find.text('e.g. 45'), findsOneWidget);
    expect(find.text('Kilometres'), findsNothing);
    expect(find.text('Travel support item'), findsNothing);
    expect(
      find.text(GroupShiftTravelController.workerTimeSectionTitle),
      findsWidgets,
    );
  });

  testWidgets('over-cap banner visible and save still works', (tester) async {
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
    when(() => shifts.createTravel('shift-1', any())).thenAnswer((_) async => saved);

    dynamic popped;
    controller = GroupShiftTravelController(
      shiftsRepository: shifts,
      args: GroupShiftTravelArgs(shift: _shift()),
      onPop: (result) => popped = result,
      mmmCategoryOverride: 1,
    );
    controller.setClaimKind(TravelClaimKind.labour);
    controller.setQuantity('45');
    controller.step.value = GroupShiftTravelController.reviewStep;

    await pumpTravelView(tester, travelController: controller);

    expect(find.text(GroupShiftTravelController.overCapBannerTitle), findsOneWidget);
    expect(find.textContaining('You can still save'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(popped, same(saved));
    final body =
        verify(() => shifts.createTravel('shift-1', captureAny())).captured.single
            as ShiftTravelWrite;
    expect(body.claimKind, TravelClaimKind.labour);
    expect(body.quantityMinutes, '45');
  });
}
