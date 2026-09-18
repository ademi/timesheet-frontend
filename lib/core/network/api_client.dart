import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;

import '../constants/app_constants.dart';
import '../services/token_refresh_service.dart';
import '../services/token_storage.dart';
import 'api_client_networking.dart';
import 'auth_interceptor.dart';
import 'cert_pins.dart';

/// Single Dio client for the contractor domain (design §3.2).
///
/// All datasources use [ApiClient.dio] / [plainDio].
///
/// [plainDio] — unauthenticated auth (`/v1/auth/login`, `/v1/auth/refresh`);
/// [dio] — authenticated calls (Bearer via [AuthInterceptor]).
///
/// Certificate pinning (F-fe-001): SPKI pins applied on IO platforms when
/// [AppConstants.baseUrl] is HTTPS. Web uses browser TLS only.
/// Release builds refuse non-HTTPS base URLs ([assertReleaseHttps]).
class ApiClient {
  // Pins live in [CertPins] (eng-review D4).

  static final _baseOptions = BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 1),
    headers: const {
      Headers.contentTypeHeader: Headers.jsonContentType,
      Headers.acceptHeader: Headers.jsonContentType,
    },
  );

  ApiClient._({
    required TokenStorage tokenStorage,
    required this.plainDio,
    required this.refreshService,
    required this.dio,
  }) {
    configureApiClientNetworking(
      plainDio: plainDio,
      dio: dio,
      baseUrl: AppConstants.baseUrl,
      pins: CertPins.all,
      isRelease: kReleaseMode,
    );
    dio.interceptors.add(
      AuthInterceptor(
        storage: tokenStorage,
        refreshService: refreshService,
        authenticatedDio: dio,
      ),
    );
  }

  static ApiClient? _instance;

  factory ApiClient(TokenStorage tokenStorage) {
    return _instance ??= ApiClient._create(tokenStorage);
  }

  static ApiClient _create(TokenStorage tokenStorage) {
    final plainDio = Dio(_baseOptions);
    final refreshService = TokenRefreshService(
      storage: tokenStorage,
      plainDio: plainDio,
    );
    final dio = Dio(_baseOptions);
    return ApiClient._(
      tokenStorage: tokenStorage,
      plainDio: plainDio,
      refreshService: refreshService,
      dio: dio,
    );
  }

  /// Test-only: clear singleton between tests.
  @visibleForTesting
  static void resetForTest() => _instance = null;

  final Dio plainDio;
  final Dio dio;
  final TokenRefreshService refreshService;
}
