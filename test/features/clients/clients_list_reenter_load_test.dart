import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/shared/models/profile_photo_models.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

final _now = DateTime.utc(2026, 10, 10, 9);

ClientOut _client(String id) => ClientOut(
  id: id,
  tenantId: 'tenant-1',
  fullName: 'Client $id',
  status: 'active',
  metadata: const {},
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late _MockClientsRepository clients;
  late _MockSessionService session;
  late ClientsController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    clients = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => clients.listClients(),
    ).thenAnswer((_) async => [_client('c1'), _client('c2')]);
    when(
      () => clients.getClientProfilePhoto(any()),
    ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));
    controller = ClientsController(repository: clients, session: session);
  });

  tearDown(Get.reset);

  Future<void> waitForPhotos(int count) async {
    for (var i = 0; i < 40; i++) {
      if (controller.photosByClient.length >= count) return;
      await Future<void>.delayed(Duration.zero);
    }
    fail(
      'Timed out waiting for ${controller.photosByClient.length}/$count photos',
    );
  }

  group('isClientsListSurface', () {
    test('matches directory only, not onboarding/detail/form', () {
      expect(
        ClientsController.isClientsListSurface(AppRoutes.staffClients),
        isTrue,
      );
      expect(
        ClientsController.isClientsListSurface('${AppRoutes.staffClients}/'),
        isTrue,
      );
      expect(
        ClientsController.isClientsListSurface(AppRoutes.staffClientOnboarding),
        isFalse,
      );
      expect(
        ClientsController.isClientsListSurface(
          '${AppRoutes.staffClientOnboarding}?step=0',
        ),
        isFalse,
      );
      expect(
        ClientsController.isClientsListSurface(
          '${AppRoutes.staffClientDetail}?id=c1',
        ),
        isFalse,
      );
      expect(
        ClientsController.isClientsListSurface(AppRoutes.staffClientForm),
        isFalse,
      );
    });
  });

  group('load photo cache + guards', () {
    test('does not clear cached photos; only fetches missing ids', () async {
      await controller.load();
      await waitForPhotos(2);
      verify(() => clients.listClients()).called(1);
      verify(() => clients.getClientProfilePhoto('c1')).called(1);
      verify(() => clients.getClientProfilePhoto('c2')).called(1);

      clearInteractions(clients);
      when(
        () => clients.listClients(),
      ).thenAnswer((_) async => [_client('c1'), _client('c2'), _client('c3')]);
      when(
        () => clients.getClientProfilePhoto(any()),
      ).thenAnswer((_) async => const ProfilePhotoOut(hasPhoto: false));

      await controller.load();
      await waitForPhotos(3);
      verify(() => clients.listClients()).called(1);
      verifyNever(() => clients.getClientProfilePhoto('c1'));
      verifyNever(() => clients.getClientProfilePhoto('c2'));
      verify(() => clients.getClientProfilePhoto('c3')).called(1);
      expect(controller.photosByClient.containsKey('c1'), isTrue);
      expect(controller.photosByClient.containsKey('c3'), isTrue);
    });

    test('soft load within TTL is a no-op', () async {
      await controller.load();
      await waitForPhotos(2);
      clearInteractions(clients);

      await controller.load(soft: true);
      verifyNever(() => clients.listClients());
      verifyNever(() => clients.getClientProfilePhoto(any()));
    });

    test('coalesces concurrent load() calls into one list fetch', () async {
      final gate = Completer<List<ClientOut>>();
      when(() => clients.listClients()).thenAnswer((_) => gate.future);

      final first = controller.load();
      final second = controller.load();
      expect(identical(first, second), isTrue);

      gate.complete([_client('c1')]);
      await Future.wait([first, second]);
      verify(() => clients.listClients()).called(1);
    });

    test('soft TTL spans typical window-focus gaps (45s)', () {
      expect(ClientsController.softLoadTtl, const Duration(seconds: 45));
    });
  });
}
