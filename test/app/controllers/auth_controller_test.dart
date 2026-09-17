import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rostiq/app/controllers/auth_controller.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';
import 'package:rostiq/features/visits/sync/outbox_models.dart';
import 'package:rostiq/features/visits/sync/outbox_store.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

void main() {
  late _MockAuthRepository authRepository;
  late _MockNdisCatalogueRepository catalogueRepository;
  late AuthController controller;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory =
        await Directory.systemTemp.createTemp('rostiq_auth_logout_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return storageDirectory.path;
      }
      return null;
    });
  });

  tearDownAll(() async {
    await storageDirectory.delete(recursive: true);
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    authRepository = _MockAuthRepository();
    catalogueRepository = _MockNdisCatalogueRepository();
    when(() => authRepository.logout()).thenAnswer((_) async {});
    controller = AuthController(authRepository: authRepository);
    Get.put(controller);
    Get.put<NdisCatalogueRepository>(catalogueRepository);
  });

  tearDown(Get.reset);

  test('logout throws when clock outbox pending without confirm', () async {
    await GetStorage.init('auth_logout_outbox_test');
    final box = GetStorage('auth_logout_outbox_test');
    await box.erase();
    final outbox = OutboxStore(box);
    Get.put<OutboxStore>(outbox);
    await outbox.append(
      ClockOutboxItem(
        clientEventId: 'e1',
        visitId: 'v1',
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: DateTime.utc(2026, 9, 7, 8).toIso8601String(),
        locationStatus: 'unavailable',
        locationFailReason: 'offline',
        deviceOffline: true,
      ),
    );

    await expectLater(
      controller.logout(),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'outbox_not_empty')),
    );
    verifyNever(() => authRepository.logout());
  });

  testWidgets(
    'logout clears NDIS catalogue cache when repository is registered',
    (tester) async {
      await tester.pumpWidget(
        GetMaterialApp(
          home: const SizedBox(),
          getPages: [
            GetPage(name: AppRoutes.gateway, page: () => const SizedBox()),
          ],
        ),
      );

      await controller.logout();

      verify(() => catalogueRepository.clearCache()).called(1);
    },
  );
}
