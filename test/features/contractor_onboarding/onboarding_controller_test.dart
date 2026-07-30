import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/contractor_onboarding/controllers/onboarding_controller.dart';
import 'package:rostiq/features/contractor_onboarding/data/onboarding_progress_store.dart';
import 'package:rostiq/features/contractor_onboarding/data/repositories/compliance_repository.dart';

class _MockComplianceRepository extends Mock implements ComplianceRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokenStorage extends Fake implements TokenStorage {
  @override
  JwtClaims? get jwtClaims => null;
}

void main() {
  late Directory storageDirectory;
  late OnboardingProgressStore progressStore;
  late SessionService sessionService;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'rostiq_onboarding_controller_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return storageDirectory.path;
          }
          return null;
        });
    await GetStorage.init();
  });

  tearDownAll(() async {
    await storageDirectory.delete(recursive: true);
  });

  setUp(() {
    Get.reset();
    progressStore = OnboardingProgressStore();
    sessionService = SessionService(
      tokenStorage: _FakeTokenStorage(),
      authRepository: _MockAuthRepository(),
      onboardingProgressStore: progressStore,
    );
    sessionService.contractorId.value = 'contractor-a';
    sessionService.needsEngagementWork.value = true;
    Get.put<SessionService>(sessionService);
  });

  tearDown(Get.reset);

  test(
    'resolves engagement when restored platform progress is complete',
    () async {
      await progressStore.markPlatformComplete('contractor-a');
      final controller = OnboardingController(
        repository: _MockComplianceRepository(),
        progressStore: progressStore,
      );

      expect(
        controller.resolveFirstIncompleteStep(),
        OnboardingStep.engagement,
      );
    },
  );
}
