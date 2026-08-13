import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/contractor_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSessionService extends Mock implements SessionService {}

VisitOut _visit({required String id}) {
  final t = DateTime.utc(2026, 8, 13, 9);
  return VisitOut(
    id: id,
    tenantId: 't',
    jobId: 'j',
    contractorId: 'c',
    scheduledStart: t,
    scheduledEnd: t.add(const Duration(hours: 2)),
    status: 'scheduled',
    source: 'claim',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: t,
    updatedAt: t,
  );
}

ShiftOut _claimedShift(String visitId) {
  final t = DateTime.utc(2026, 8, 13, 9);
  return ShiftOut(
    id: 'shift-1',
    tenantId: 't',
    jobId: 'j',
    jobTitle: 'Support',
    scheduledStart: t,
    scheduledEnd: t.add(const Duration(hours: 2)),
    requiredSlots: 2,
    openSlots: 1,
    status: 'published',
    assignments: [
      ShiftAssignmentOut(
        id: 'a1',
        contractorId: 'c',
        contractorName: 'Alex',
        visitId: visitId,
        source: 'claim',
        status: 'active',
      ),
    ],
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockShiftsRepository shifts;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    visits = _MockVisitsRepository();
    shifts = _MockShiftsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <VisitOut>[]);
  });

  tearDown(Get.reset);

  test('selectTab open calls listOpenShifts', () async {
    when(
      () => shifts.listOpenShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (_) async => [
        OpenShiftOut(
          id: 'shift-1',
          jobTitle: 'Support',
          scheduledStart: DateTime.utc(2026, 8, 13, 9),
          scheduledEnd: DateTime.utc(2026, 8, 13, 11),
          requiredSlots: 2,
          openSlots: 1,
        ),
      ],
    );

    final controller = ContractorVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      session: session,
    );
    Get.put(controller);

    await controller.selectTab('open');

    expect(controller.selectedTab.value, 'open');
    expect(controller.openShifts, hasLength(1));
    verify(
      () => shifts.listOpenShifts(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).called(1);
  });

  testWidgets('claim adds visit and switches to mine tab', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const SizedBox.shrink()),
          GetPage(
            name: AppRoutes.contractorVisitDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );

    const visitId = 'visit-claimed';
    when(() => shifts.claimShift('shift-1')).thenAnswer(
      (_) async => _claimedShift(visitId),
    );
    when(() => visits.getVisit(visitId)).thenAnswer(
      (_) async => _visit(id: visitId),
    );

    final controller = ContractorVisitsController(
      repository: visits,
      shiftsRepository: shifts,
      session: session,
    );
    Get.put(controller);
    controller.selectedTab.value = 'open';
    controller.openShifts.assignAll([
      OpenShiftOut(
        id: 'shift-1',
        jobTitle: 'Support',
        scheduledStart: DateTime.utc(2026, 8, 13, 9),
        scheduledEnd: DateTime.utc(2026, 8, 13, 11),
        requiredSlots: 2,
        openSlots: 1,
      ),
    ]);

    await controller.claimShift('shift-1');

    expect(controller.selectedTab.value, 'mine');
    expect(controller.visits.any((v) => v.id == visitId), isTrue);
    expect(controller.openShifts, isEmpty);
  });
}
