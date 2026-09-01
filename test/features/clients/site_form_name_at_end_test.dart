import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/widgets/site_form_fields.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 1, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Sam Lee',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockJobsRepository jobs;
  late _MockSessionService session;
  late ClientsController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(() => clients.getClientProfilePhoto(any())).thenAnswer(
      (_) async => const ProfilePhotoOut(hasPhoto: false),
    );
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('nameAtEnd renders name field after access notes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SiteFormFields(
              controller: controller,
              nameAtEnd: true,
            ),
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    expect(fields, findsWidgets);

    final accessNotes = find.widgetWithText(TextField, 'Access notes');
    final nameField = find.widgetWithText(TextField, 'Name *');
    expect(accessNotes, findsOneWidget);
    expect(nameField, findsOneWidget);

    final accessY = tester.getTopLeft(accessNotes).dy;
    final nameY = tester.getTopLeft(nameField).dy;
    expect(nameY, greaterThan(accessY));
  });

  testWidgets('name field shows Home, Work placeholder when nameAtEnd', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SiteFormFields(
            controller: controller,
            nameAtEnd: true,
          ),
        ),
      ),
    );

    final nameField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Name *'),
    );
    expect(nameField.decoration?.hintText, 'Home, Work');
  });
}
