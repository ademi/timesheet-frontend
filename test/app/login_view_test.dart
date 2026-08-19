import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/controllers/auth_controller.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/app/views/login_view.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late AuthController controller;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    controller = AuthController(authRepository: _MockAuthRepository());
    Get.put(controller);
  });

  tearDown(Get.reset);

  testWidgets('shows paths to contractor register and provider signup', (
    tester,
  ) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    expect(find.text('Register as contractor'), findsOneWidget);
    expect(find.text('Provider signup'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
