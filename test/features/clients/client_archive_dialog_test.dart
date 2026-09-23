import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/client_detail_view.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 9, 23, 9);

final _activeClient = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Patient',
  status: 'active',
  email: 'demo@example.com',
  phone: '+61400000100',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

final _archivedClient = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Patient',
  status: 'archived',
  email: 'demo@example.com',
  phone: '+61400000100',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockJobsRepository jobs;
  late _MockSessionService session;
  late ClientsController controller;

  void stubCommon(ClientOut client) {
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer((_) async => [client]);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => clients.listClientTypes()).thenAnswer((_) async => []);
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    when(
      () => clients.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);
    when(() => clients.listStrengthsNeeds(any())).thenAnswer((_) async => []);
  }

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    stubCommon(_activeClient);
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: jobs,
    );
    controller.selected.value = _activeClient;
    controller.hydrateOverviewDrafts();
    Get.put(controller);
  });

  tearDown(() {
    Get.closeAllSnackbars();
    Get.reset();
  });

  testWidgets('archive dialog explains retention, not permanent wipe', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.byTooltip('Archive'), findsOneWidget);
    await tester.tap(find.byTooltip('Archive'));
    await tester.pump(); // open dialog

    expect(find.textContaining('Archive'), findsWidgets);
    expect(find.textContaining('cannot be undone'), findsNothing);
    expect(
      find.textContaining('kept for legal and audit requirements'),
      findsOneWidget,
    );
    expect(find.text('Archive'), findsWidgets);
  });

  testWidgets('archived client detail is read-only', (tester) async {
    controller.selected.value = _archivedClient;
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    expect(find.byTooltip('Edit'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
    expect(find.byTooltip('Archive'), findsNothing);
    expect(find.textContaining('Archived'), findsOneWidget);
  });
}
