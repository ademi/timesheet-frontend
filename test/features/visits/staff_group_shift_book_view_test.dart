import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/views/staff_group_shift_book_view.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

class _MockClientsRepository extends Mock implements ClientsRepository {}

void main() {
  late _MockClientsRepository clientsRepository;

  final clients = [
    ClientOut(
      id: 'client-a',
      tenantId: 'tenant-1',
      fullName: 'Alice Example',
      status: 'active',
      metadata: const {},
      createdAt: DateTime.utc(2026, 9, 10),
      updatedAt: DateTime.utc(2026, 9, 10),
    ),
    ClientOut(
      id: 'client-b',
      tenantId: 'tenant-1',
      fullName: 'Bob Example',
      status: 'active',
      metadata: const {},
      createdAt: DateTime.utc(2026, 9, 10),
      updatedAt: DateTime.utc(2026, 9, 10),
    ),
  ];

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clientsRepository = _MockClientsRepository();
    when(
      () => clientsRepository.listClients(),
    ).thenAnswer((_) async => clients);

    Get.put(
      StaffVisitsController(
        repository: _MockVisitsRepository(),
        shiftsRepository: _MockShiftsRepository(),
        jobsRepository: _MockJobsRepository(),
        engagementsRepository: _MockEngagementsRepository(),
        session: _MockSessionService(),
        clientsRepository: clientsRepository,
      ),
    );
  });

  tearDown(Get.reset);

  Future<void> pumpWizard(WidgetTester tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: StaffGroupShiftBookView()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectAliceAsHost(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('group-shift-host')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alice Example').last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the first wizard step', (tester) async {
    await pumpWizard(tester);

    expect(find.textContaining('Step 1 of 3'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('selecting host seeds a 100 percent capacity row', (
    tester,
  ) async {
    await pumpWizard(tester);
    await selectAliceAsHost(tester);

    expect(find.text('Alice Example (host)'), findsOneWidget);
    final capacityField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Capacity (%)'),
    );
    expect(capacityField.controller!.text, '100');
    expect(find.text('Sum: 100% · Remaining: 0%'), findsOneWidget);
  });

  testWidgets('sum footer updates when capacity is edited', (tester) async {
    await pumpWizard(tester);
    await selectAliceAsHost(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Capacity (%)'),
      '60',
    );
    await tester.pump();

    expect(find.text('Sum: 60% · Remaining: 40%'), findsOneWidget);
  });
}
