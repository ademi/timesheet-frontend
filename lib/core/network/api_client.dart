import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../services/token_storage.dart';
import 'auth_interceptor.dart';

/// Auth [ApiClient]: [plainDio] for unauthenticated auth calls (`/v1/auth/login`, `/v1/auth/refresh`);
/// [dio] for authenticated auth calls (Bearer from [AuthInterceptor], e.g. `/v1/auth/logout`).
class ApiClient {
  // Certificate pinning (FE-8): set [_spkiPin] from production cert SPKI hash.
  // dio_pinning_interceptor is unavailable on pub.dev; add interceptor when wired.
  // ignore: unused_field
  static const _spkiPin = 'PASTE_BASE64_SPKI_PIN_HERE';

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

  final Dio plainDio;
  final Dio dio;
}
