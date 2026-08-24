import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;

import '../constants/app_constants.dart';
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

  ApiClient._(TokenStorage tokenStorage)
      : plainDio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 1),
            headers: const {
              Headers.contentTypeHeader: Headers.jsonContentType,
              Headers.acceptHeader: Headers.jsonContentType,
            },
          ),
        ),
        dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 1),
            headers: const {
              Headers.contentTypeHeader: Headers.jsonContentType,
              Headers.acceptHeader: Headers.jsonContentType,
            },
          ),
        ) {
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
        plainDio: plainDio,
        authenticatedDio: dio,
      ),
    );
  }

  static ApiClient? _instance;

  factory ApiClient(TokenStorage tokenStorage) {
    return _instance ??= ApiClient._(tokenStorage);
  }

  /// Test-only: clear singleton between tests.
  @visibleForTesting
  static void resetForTest() => _instance = null;

  final Dio plainDio;
  final Dio dio;
}
