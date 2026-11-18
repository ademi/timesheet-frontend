import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/controllers/landing_auth_handoff_controller.dart';
import 'package:rostiq/app/data/models/auth/auth_token_model.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';

class _MockSessionService extends Mock implements SessionService {}

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late _MockSessionService session;

  setUpAll(() {
    registerFallbackValue(
      const AuthTokenModel(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'bearer',
      ),
    );
  });

  setUp(() {
    Get.testMode = true;
    Get.reset();
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage();
    session = _MockSessionService();
    when(() => session.clear()).thenAnswer((_) async {});
    when(() => session.applyAuthTokens(any())).thenAnswer((_) async {});
    when(() => session.hydrateFromMeContext()).thenAnswer((_) async {});
    when(() => session.mustChangePassword).thenReturn(false.obs);
    when(() => session.resolvePostLoginRoute()).thenReturn(AppRoutes.staffHome);
  });

  tearDown(Get.reset);

  test('persists hash tokens and routes tenant member to staff home', () async {
    final access = _fakeJwt({
      'sub': 'u1',
      'tenant_id': 'ten-1',
      'actor_type': 'tenant_member',
      'permissions': ['auth.session'],
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    });

    final navigated = <String>[];
    final c = LandingAuthHandoffController(
      tokenStorage: storage,
      sessionService: session,
      pathOverride: AppRoutes.adminPanel,
      fragmentOverride:
          'access_token=$access&refresh_token=ref-1&token_type=bearer'
          '&tenant_id=ten-1&admin_must_change_password=false',
      navigateOverride: navigated.add,
    );

    await c.runForTest();

    expect(storage.accessToken, access);
    expect(storage.refreshToken, 'ref-1');
    expect(storage.lastTenantId, 'ten-1');
    verify(() => session.applyAuthTokens(any())).called(1);
    expect(navigated, [AppRoutes.staffHome]);
  });

  test('change-password path forces first-login destination', () async {
    final access = _fakeJwt({
      'sub': 'u1',
      'tenant_id': 'ten-1',
      'actor_type': 'tenant_member',
      'permissions': ['auth.session'],
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
    });

    final navigated = <String>[];
    final c = LandingAuthHandoffController(
      tokenStorage: storage,
      sessionService: session,
      pathOverride: AppRoutes.changePassword,
      fragmentOverride:
          'access_token=$access&refresh_token=ref-1'
          '&admin_must_change_password=true',
      navigateOverride: navigated.add,
    );

    await c.runForTest();

    expect(storage.accessToken, access);
    expect(navigated, [AppRoutes.firstLogin]);
  });
}
