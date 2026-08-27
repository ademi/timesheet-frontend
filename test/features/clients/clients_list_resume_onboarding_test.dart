import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/views/clients_list_view.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 8, 26, 9);

ClientOut _client({
  required String id,
  required String name,
  Map<String, dynamic> metadata = const {},
}) {
  return ClientOut(
    id: id,
    tenantId: 'tenant-1',
    fullName: name,
    status: 'active',
    metadata: metadata,
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late ClientsController controller;

  final complete = _client(id: 'c1', name: 'Complete Client');
  final incomplete = _client(
    id: 'c2',
    name: 'Incomplete Client',
    metadata: const {'onboarding_incomplete': true},
  );

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(() => clients.listClients()).thenAnswer(
      (_) async => [complete, incomplete],
    );
    when(() => clients.getClientProfilePhoto(any())).thenAnswer(
      (_) async => const ProfilePhotoOut(hasPhoto: false),
    );
    controller = ClientsController(
      repository: clients,
      session: session,
    );
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('incomplete card shows badge and Continue onboarding', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        getPages: [
          GetPage(
            name: '/',
            page: () => const ClientsListView(),
          ),
          GetPage(
            name: AppRoutes.staffClientOnboarding,
            page: () => const Scaffold(body: Text('Onboarding wizard')),
          ),
        ],
        initialRoute: '/',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incomplete Client'), findsNothing);

    await tester.tap(find.text('Show incomplete'));
    await tester.pumpAndSettle();

    expect(find.text('Incomplete Client'), findsOneWidget);
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.text('Continue onboarding'), findsOneWidget);

    await tester.tap(find.text('Continue onboarding'));
    await tester.pumpAndSettle();

    expect(find.text('Onboarding wizard'), findsOneWidget);
  });
}
