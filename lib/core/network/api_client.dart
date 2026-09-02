import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../services/token_refresh_service.dart';
import '../services/token_storage.dart';
import 'auth_interceptor.dart';

/// Single Dio client for the contractor domain (design §3.2).
///
/// All datasources use [ApiClient.dio] / [plainDio].
///
/// [plainDio] — unauthenticated auth (`/v1/auth/login`, `/v1/auth/refresh`);
/// [dio] — authenticated calls (Bearer via [AuthInterceptor]).
class ApiClient {
  // Certificate pinning (FE-8): set [_spkiPin] from production cert SPKI hash.
  // dio_pinning_interceptor is unavailable on pub.dev; add interceptor when wired.
  // ignore: unused_field
  static const _spkiPin = 'PASTE_BASE64_SPKI_PIN_HERE';

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

  final Dio plainDio;
  final Dio dio;
  final TokenRefreshService refreshService;
}
