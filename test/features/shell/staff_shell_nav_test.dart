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
import 'package:rostiq/features/contractor_onboarding/data/onboarding_progress_store.dart';
import 'package:rostiq/features/shell/staff_shell.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokenStorage extends Fake implements TokenStorage {
  JwtClaims? claims;

  @override
  JwtClaims? get jwtClaims => claims;

  @override
  String? get accessToken => claims == null ? null : 'token';

  @override
  String? get lastTenantId => null;

  @override
  Future<void> persistLastTenantSelection({
    required String tenantId,
    String? engagementId,
  }) async {}
}

void main() {
  late _FakeTokenStorage tokenStorage;
  late SessionService session;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'rostiq_staff_shell_nav_',
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
    Get.testMode = true;
    tokenStorage = _FakeTokenStorage();
    session = SessionService(
      tokenStorage: tokenStorage,
      authRepository: _MockAuthRepository(),
      onboardingProgressStore: OnboardingProgressStore(),
    );
    Get.put<SessionService>(session);
  });

  tearDown(Get.reset);

  test('destinations include Workforce when contractors.read present', () {
    tokenStorage.claims = const JwtClaims(
      sub: 'u1',
      tenantId: 't1',
      permissions: ['auth.session', 'contractors.read', 'jobs.read'],
      actorType: 'tenant_member',
      iat: 1,
      exp: 2,
    );
    final labels = StaffShellNav.destinations().map((d) => d.label).toList();
    expect(labels, contains('Home'));
    expect(labels, contains('Workforce'));
    expect(labels, contains('Jobs'));
  });

  test('destinations fall back to Home+Settings when no claims', () {
    tokenStorage.claims = null;
    final labels = StaffShellNav.destinations().map((d) => d.label).toList();
    expect(labels, contains('Home'));
    expect(labels, contains('Settings'));
    expect(labels, isNot(contains('Workforce')));
  });
}
