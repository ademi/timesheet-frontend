import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
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

ContractorVisitsController _controller() {
  final visits = _MockVisitsRepository();
  final session = _MockSessionService();
  when(() => session.hasPermission(any())).thenReturn(false);
  return ContractorVisitsController(
    repository: visits,
    shiftsRepository: _MockShiftsRepository(),
    session: session,
  );
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('resolvedVisitId reads string id from schedule navigation',
      (tester) async {
    late ContractorVisitsController controller;

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => ElevatedButton(
              onPressed: () =>
                  Get.toNamed('/detail', arguments: 'sched-visit-1'),
              child: const Text('open'),
            ),
          ),
          GetPage(
            name: '/detail',
            binding: BindingsBuilder(() {
              controller = _controller();
              Get.put(controller);
            }),
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(controller.selected.value, isNull);
    expect(controller.resolvedVisitId, 'sched-visit-1');
  });

  testWidgets('resolvedVisitId prefers selected over route args', (tester) async {
    late ContractorVisitsController controller;
    final visit = _visit(id: 'selected-visit');

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () => ElevatedButton(
              onPressed: () =>
                  Get.toNamed('/detail', arguments: 'route-visit-id'),
              child: const Text('open'),
            ),
          ),
          GetPage(
            name: '/detail',
            binding: BindingsBuilder(() {
              controller = _controller();
              controller.selected.value = visit;
              Get.put(controller);
            }),
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(controller.resolvedVisitId, 'selected-visit');
  });
}
