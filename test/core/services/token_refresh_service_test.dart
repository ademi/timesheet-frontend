import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/services/token_refresh_service.dart';
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

  group('TokenRefreshService', () {
    late TokenStorage storage;
    late Dio plainDio;
    late TokenRefreshService service;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      storage = TokenStorage();
      plainDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      service = TokenRefreshService(storage: storage, plainDio: plainDio);
    });

    test('refreshIfNeeded returns notNeeded for valid access token', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _futureExp()}),
        refreshToken: 'refresh',
      );

      final outcome = await service.refreshIfNeeded();

      expect(outcome, TokenRefreshOutcome.notNeeded);
    });

    test('refreshIfNeeded refreshes when access token is expired', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _pastExp()}),
        refreshToken: 'refresh',
      );

      plainDio.httpClientAdapter = _RefreshAdapter();

      final outcome = await service.refreshIfNeeded();

      expect(outcome, TokenRefreshOutcome.success);
      expect(storage.hasValidAccessToken, isTrue);
      expect(storage.refreshToken, 'new-refresh');
    });

    test('refreshIfNeeded clears tokens when refresh is rejected', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _pastExp()}),
        refreshToken: 'refresh',
      );

      plainDio.httpClientAdapter = _RejectRefreshAdapter();

      final outcome = await service.refreshIfNeeded();

      expect(outcome, TokenRefreshOutcome.invalidRefreshToken);
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });

    test('refreshIfNeeded keeps tokens on transient failure', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _pastExp()}),
        refreshToken: 'refresh',
      );

      plainDio.httpClientAdapter = _NetworkErrorAdapter();

      final outcome = await service.refreshIfNeeded();

      expect(outcome, TokenRefreshOutcome.transientFailure);
      expect(storage.refreshToken, 'refresh');
    });

    test('refreshIfNeeded keeps tokens on 403 from refresh endpoint', () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _pastExp()}),
        refreshToken: 'refresh',
      );

      plainDio.httpClientAdapter = _ForbiddenRefreshAdapter();

      final outcome = await service.refreshIfNeeded();

      expect(outcome, TokenRefreshOutcome.transientFailure);
      expect(storage.refreshToken, 'refresh');
    });

    test('refreshIfNeeded returns invalidRefreshToken when refresh missing',
        () async {
      await storage.persistTokens(
        accessToken: _fakeJwt({'exp': _pastExp()}),
        refreshToken: '',
      );

      final outcome = await service.refreshIfNeeded();

      expect(outcome, TokenRefreshOutcome.invalidRefreshToken);
    });
  });
}

int _futureExp() =>
    DateTime.now().toUtc().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
    1000;

int _pastExp() =>
    DateTime.now().toUtc().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
    1000;

class _RefreshAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = jsonEncode({
      'access_token': _fakeJwt({'exp': _futureExp()}),
      'refresh_token': 'new-refresh',
      'token_type': 'bearer',
    });
    return ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

class _RejectRefreshAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"detail":"invalid"}', 401, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

class _ForbiddenRefreshAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{"detail":"forbidden"}', 403, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }
}

class _NetworkErrorAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }
}
