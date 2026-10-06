import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/shifts/data/repositories/shifts_repository.dart';
import 'package:rostiq/features/visits/controllers/contractor_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/views/contractor_visit_detail_view.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockShiftsRepository extends Mock implements ShiftsRepository {}

class _MockSessionService extends Mock implements SessionService {}

VisitOut _visit({
  String status = 'checked_in',
  List<VisitFormRequirement> forms = const [],
}) {
  final t = DateTime.utc(2026, 10, 6, 9);
  return VisitOut(
    id: 'v1',
    tenantId: 't1',
    jobId: 'j1',
    contractorId: 'c1',
    jobTitle: 'Morning support',
    scheduledStart: t,
    scheduledEnd: t.add(const Duration(hours: 3)),
    status: status,
    source: 'claim',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    formRequirements: forms,
    createdAt: t,
    updatedAt: t,
  );
}

VisitFormRequirement _form(String id, String name) => VisitFormRequirement(
  formTemplateId: id,
  name: name,
  isRequired: true,
  schemaJson: const {
    'fields': [
      {'id': 'n1', 'type': 'text', 'label': 'Note', 'required': false},
    ],
  },
);

void main() {
  late ContractorVisitsController controller;
  late _MockVisitsRepository visits;
  late _MockSessionService session;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    visits = _MockVisitsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);

    final seeded = _visit(
      forms: [
        _form('f1', 'Progress note'),
        _form('f2', 'Incident report'),
        _form('f3', 'Medication chart'),
      ],
    );
    when(() => visits.getVisit(any())).thenAnswer((_) async => seeded);

    controller = ContractorVisitsController(
      repository: visits,
      shiftsRepository: _MockShiftsRepository(),
      session: session,
    );
    controller.selected.value = seeded;
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('forms accordion collapses; only one open at a time', (
    tester,
  ) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: ContractorVisitDetailView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forms'), findsOneWidget);
    expect(find.byKey(const Key('visit-forms-summary')), findsOneWidget);
    expect(find.text('3 remaining'), findsOneWidget);

    // First incomplete required form starts open — its field is visible.
    expect(find.text('Note'), findsOneWidget);

    // Collapse by tapping the open header.
    await tester.tap(find.text('Progress note'));
    await tester.pumpAndSettle();
    expect(find.text('Note'), findsNothing);

    // Open a different form.
    await tester.tap(find.text('Incident report'));
    await tester.pumpAndSettle();
    expect(find.text('Note'), findsOneWidget);

    // Complete stays pinned in the footer while checked in.
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('status chip and sticky check-in for scheduled visit', (
    tester,
  ) async {
    final scheduled = _visit(status: 'scheduled', forms: const []);
    when(() => visits.getVisit(any())).thenAnswer((_) async => scheduled);
    controller.selected.value = scheduled;

    await tester.pumpWidget(
      const GetMaterialApp(home: ContractorVisitDetailView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Check in'), findsOneWidget);
    expect(find.text('Forms'), findsNothing);
  });
}
