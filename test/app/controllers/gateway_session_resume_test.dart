import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/app/routes/middlewares/auth_route_utils.dart';
import 'package:rostiq/core/services/token_storage.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('auth_route_utils session resume', () {
    test('isUnauthenticatedEntryLocation only for gateway/empty', () {
      expect(isUnauthenticatedEntryLocation(null), isTrue);
      expect(isUnauthenticatedEntryLocation(''), isTrue);
      expect(isUnauthenticatedEntryLocation('/'), isTrue);
      expect(isUnauthenticatedEntryLocation(AppRoutes.gateway), isTrue);
      expect(
        isUnauthenticatedEntryLocation(AppRoutes.staffClientDetail),
        isFalse,
      );
      expect(
        isUnauthenticatedEntryLocation('${AppRoutes.staffClientDetail}?id=1'),
        isFalse,
      );
    });

    test('shouldNavigateAfterSessionResume respects override', () {
      expect(
        shouldNavigateAfterSessionResume(entryLocation: AppRoutes.gateway),
        isTrue,
      );
      expect(
        shouldNavigateAfterSessionResume(
          entryLocation: AppRoutes.staffClientDetail,
        ),
        isFalse,
      );
      expect(
        shouldNavigateAfterSessionResume(
          entryLocation: '/staff/clients/onboarding?id=c1&step=3',
        ),
        isFalse,
      );
    });

    test('locationPath strips query', () {
      expect(
        locationPath('/staff/clients/detail?id=abc'),
        '/staff/clients/detail',
      );
    });

    test('redirectWhenMustChangePassword sends to first-login', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = TokenStorage();
      await storage.persistTokens(
        accessToken: _fakeJwt({
          'exp':
              DateTime.now()
                  .add(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000,
          'mcp': true,
          'actor_type': 'tenant_member',
        }),
        refreshToken: 'refresh',
      );
      Get.testMode = true;
      Get.reset();
      Get.put<TokenStorage>(storage);

      expect(
        redirectWhenMustChangePassword(AppRoutes.staffHome)?.name,
        AppRoutes.firstLogin,
      );
      expect(redirectWhenMustChangePassword(AppRoutes.firstLogin), isNull);
      Get.reset();
    });

    test('redirectWrongActor blocks contractor on staff routes', () {
      expect(
        redirectWrongActor(
          route: AppRoutes.staffHome,
          actorType: 'contractor',
        )?.name,
        AppRoutes.wrongActor,
      );
      expect(
        redirectWrongActor(
          route: AppRoutes.staffHome,
          actorType: 'tenant_member',
        ),
        isNull,
      );
    });
  });
}
