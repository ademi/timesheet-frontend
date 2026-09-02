import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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

  setUp(() {
    Get.testMode = true;
    Get.reset();
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('redirectWhenUnauthenticated allows expired access with refresh token',
      () async {
    final storage = TokenStorage();
    await storage.persistTokens(
      accessToken: _fakeJwt({'exp': 1}),
      refreshToken: 'refresh',
    );
    Get.put<TokenStorage>(storage);

    expect(redirectWhenUnauthenticated(), isNull);
  });

  test('redirectWhenUnauthenticated sends user to gateway with no credentials',
      () async {
    final storage = TokenStorage();
    Get.put<TokenStorage>(storage);

    expect(redirectWhenUnauthenticated()?.name, '/gateway');
  });
}
