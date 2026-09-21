import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/app/views/widgets/app_back_button.dart';
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

final _now = DateTime.utc(2026, 9, 1, 9);

final _client = ClientOut(
  id: 'client-1',
  tenantId: 'tenant-1',
  fullName: 'Demo Patient',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late ClientsController controller;

  void stubDetailExtras() {
    when(() => clients.listClients()).thenAnswer((_) async => [_client]);
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    when(() => clients.listClientTypes()).thenAnswer((_) async => []);
    when(
      () => clients.getClientProfile(any()),
    ).thenAnswer((_) async => const ClientProfileBundle(facts: []));
    when(() => clients.listSites(any())).thenAnswer((_) async => []);
    when(() => clients.listContacts(any())).thenAnswer((_) async => []);
    when(() => clients.listSupportPlans(any())).thenAnswer((_) async => []);
    when(() => clients.listTypeRequirements(any())).thenAnswer((_) async => []);
  }

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    stubDetailExtras();
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: _MockJobsRepository(),
    );
    controller.selected.value = _client;
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('ClientDetailView uses AppBackButton with clients fallback', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: ClientDetailView()));
    await tester.pump();

    final back = tester.widget<AppBackButton>(find.byType(AppBackButton));
    expect(back.fallbackRoute, AppRoutes.staffClients);
  });

  testWidgets(
    'ClientDetailView loads by route id when selected is null',
    (tester) async {
      controller.selected.value = null;
      clearInteractions(clients);
      when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '${AppRoutes.staffClientDetail}?id=${_client.id}',
          getPages: [
            GetPage(
              name: AppRoutes.staffClientDetail,
              page: () => const ClientDetailView(),
            ),
          ],
        ),
      );
      // Keep the controller under test (binding may not recreate it).
      if (!Get.isRegistered<ClientsController>()) {
        Get.put(controller);
      }

      await controller.ensureDetailHydratedFromRoute();
      await tester.pumpAndSettle();

      expect(find.text('Client not found.'), findsNothing);
      expect(find.text(_client.fullName), findsWidgets);
    },
  );

  test('ensureDetailHydratedFromRoute uses Get.arguments ClientOut', () async {
    controller.selected.value = null;
    clearInteractions(clients);
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    Get.routing.args = _client;

    await controller.ensureDetailHydratedFromRoute();

    expect(controller.selected.value?.id, _client.id);
    verify(() => clients.getClient(_client.id)).called(1);
  });

  test('ensureDetailHydratedFromRoute loads by parameters id', () async {
    controller.selected.value = null;
    clearInteractions(clients);
    when(() => clients.getClient(_client.id)).thenAnswer((_) async => _client);
    Get.routing.args = null;
    Get.parameters['id'] = _client.id;

    await controller.ensureDetailHydratedFromRoute();

    expect(controller.selected.value?.id, _client.id);
    verify(() => clients.getClient(_client.id)).called(1);
  });

  testWidgets('openDetail passes client id in route parameters', (tester) async {
    Get.reset();
    Get.testMode = true;
    stubDetailExtras();
    controller = ClientsController(
      repository: clients,
      session: session,
      jobsRepository: _MockJobsRepository(),
    );
    Get.put(controller);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.staffClients,
        getPages: [
          GetPage(
            name: AppRoutes.staffClients,
            page: () => const SizedBox.shrink(),
          ),
          GetPage(
            name: AppRoutes.staffClientDetail,
            page: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );

    await controller.openDetail(_client);
    await tester.pumpAndSettle();

    expect(Get.currentRoute, startsWith(AppRoutes.staffClientDetail));
    expect(Get.parameters['id'], _client.id);
    expect(controller.selected.value?.id, _client.id);
  });
}
