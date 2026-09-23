import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/contractor_schedule/controllers/contractor_schedule_controller.dart';
import 'package:rostiq/features/contractor_schedule/data/models/schedule_models.dart';
import 'package:rostiq/features/contractor_schedule/data/repositories/contractor_schedule_repository.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

class _MockRepo extends Mock implements ContractorScheduleRepository {}

class _MockSession extends Mock implements SessionService {}

void main() {
  late _MockRepo repo;
  late _MockSession session;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    repo = _MockRepo();
    session = _MockSession();
    when(() => session.contractorId).thenReturn(RxnString('c-1')..value = 'c-1');
    when(() => session.hasPermission(any())).thenReturn(true);
  });

  tearDown(Get.reset);

  testWidgets('openVisit passes VisitOut stub not bare String id', (
    tester,
  ) async {
    Object? navArgs;
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/',
        getPages: [
          GetPage(
            name: '/',
            page: () {
              final c = ContractorScheduleController(
                repository: repo,
                session: session,
              );
              return ElevatedButton(
                onPressed: () {
                  c.openVisit(
                    TimetableVisitOut(
                      id: 'sched-1',
                      tenantId: 't-1',
                      jobId: 'j-1',
                      scheduledStart: DateTime.utc(2026, 9, 23, 9),
                      scheduledEnd: DateTime.utc(2026, 9, 23, 11),
                      status: 'scheduled',
                      jobTitle: 'Support',
                      tenantName: 'Acme',
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
          GetPage(
            name: AppRoutes.contractorVisitDetail,
            page: () {
              navArgs = Get.arguments;
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(navArgs, isA<VisitOut>());
    final visit = navArgs! as VisitOut;
    expect(visit.id, 'sched-1');
    expect(visit.jobTitle, 'Support');
    expect(visit.contractorId, 'c-1');
    expect(visit.source, 'timetable');
  });

  test('toVisitOutStub maps timetable fields', () {
    final stub = TimetableVisitOut(
      id: 'v1',
      tenantId: 't1',
      jobId: 'j1',
      scheduledStart: DateTime.utc(2026, 1, 1, 9),
      scheduledEnd: DateTime.utc(2026, 1, 1, 10),
      status: 'checked_in',
      jobTitle: 'Job',
    ).toVisitOutStub(contractorId: 'c9');
    expect(stub.id, 'v1');
    expect(stub.contractorId, 'c9');
    expect(stub.status, 'checked_in');
  });
}
