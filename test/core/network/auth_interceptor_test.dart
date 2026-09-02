import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/core/network/auth_interceptor.dart';
import 'package:rostiq/core/services/token_refresh_service.dart';
import 'package:rostiq/core/services/token_storage.dart';

String _fakeJwt(Map<String, dynamic> payload) {
  final header = base64Url.encode(
    utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

int _futureExp() =>
    DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
    1000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TokenStorage storage;
  late Dio plainDio;
  late Dio authenticatedDio;
  late TokenRefreshService refreshService;

  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    storage = TokenStorage();
    Get.put<TokenStorage>(storage, permanent: true);
    plainDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    authenticatedDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    refreshService = TokenRefreshService(storage: storage, plainDio: plainDio);
    authenticatedDio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        refreshService: refreshService,
        authenticatedDio: authenticatedDio,
      ),
    );
  });

  tearDown(() {
    Get.reset();
  });

  group('AuthInterceptor', () {
    test('retries once after refresh succeeds on 401', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _futureExp()}),
        refreshToken: 'refresh',
      );

      var apiCalls = 0;
      authenticatedDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (options) async {
          if (options.path == '/v1/resource') {
            apiCalls++;
            if (apiCalls == 1) {
              return ResponseBody.fromString('{"detail":"unauthorized"}', 401);
            }
            return ResponseBody.fromString(
              '{"ok":true}',
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('not found', 404);
        },
      );
      plainDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (options) async {
          if (options.path == '/v1/auth/refresh') {
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': _fakeJwt({'exp': _futureExp()}),
                'refresh_token': 'new-refresh',
                'token_type': 'bearer',
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('not found', 404);
        },
      );

      final response = await authenticatedDio.get<Map<String, dynamic>>(
        '/v1/resource',
      );

      expect(response.statusCode, 200);
      expect(response.data?['ok'], isTrue);
      expect(apiCalls, 2);
      expect(storage.refreshToken, 'new-refresh');
    });

    test('does not clear tokens on transient refresh failure', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _futureExp()}),
        refreshToken: 'refresh',
      );

      authenticatedDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (_) async =>
            ResponseBody.fromString('{"detail":"unauthorized"}', 401),
      );
      plainDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (_) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/v1/auth/refresh'),
            type: DioExceptionType.connectionError,
          );
        },
      );

      await expectLater(
        authenticatedDio.get<Map<String, dynamic>>('/v1/resource'),
        throwsA(isA<DioException>()),
      );

      expect(storage.refreshToken, 'refresh');
      expect(storage.accessToken, isNotNull);
    });

    test('invalidates session and redirects on rejected refresh', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _futureExp()}),
        refreshToken: 'refresh',
      );

      authenticatedDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (_) async =>
            ResponseBody.fromString('{"detail":"unauthorized"}', 401),
      );
      plainDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (_) async => ResponseBody.fromString(
          '{"detail":"invalid"}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );

      await expectLater(
        authenticatedDio.get<Map<String, dynamic>>('/v1/resource'),
        throwsA(isA<DioException>()),
      );

      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });

    test('invalidates session after second 401 on retried request', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _futureExp()}),
        refreshToken: 'refresh',
      );

      var apiCalls = 0;
      authenticatedDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (options) async {
          if (options.path == '/v1/resource') {
            apiCalls++;
            return ResponseBody.fromString('{"detail":"unauthorized"}', 401);
          }
          return ResponseBody.fromString('not found', 404);
        },
      );
      plainDio.httpClientAdapter = _InterceptorTestAdapter(
        onFetch: (options) async {
          if (options.path == '/v1/auth/refresh') {
            return ResponseBody.fromString(
              jsonEncode({
                'access_token': _fakeJwt({'exp': _futureExp()}),
                'refresh_token': 'new-refresh',
                'token_type': 'bearer',
              }),
              200,
              headers: {
                Headers.contentTypeHeader: [Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('not found', 404);
        },
      );

      await expectLater(
        authenticatedDio.get<Map<String, dynamic>>('/v1/resource'),
        throwsA(isA<DioException>()),
      );

      expect(apiCalls, 2);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });
  });
}

class _InterceptorTestAdapter implements HttpClientAdapter {
  _InterceptorTestAdapter({required this.onFetch});

  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }
}
