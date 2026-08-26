import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/controllers/auth_controller.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/billing/data/repositories/ndis_catalogue_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockNdisCatalogueRepository extends Mock
    implements NdisCatalogueRepository {}

void main() {
  late _MockAuthRepository authRepository;
  late _MockNdisCatalogueRepository catalogueRepository;
  late AuthController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    authRepository = _MockAuthRepository();
    catalogueRepository = _MockNdisCatalogueRepository();
    when(() => authRepository.logout()).thenAnswer((_) async {});
    controller = AuthController(authRepository: authRepository);
    Get.put(controller);
    Get.put<NdisCatalogueRepository>(catalogueRepository);
  });

  tearDown(Get.reset);

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
