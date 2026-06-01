import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../services/token_storage.dart';
import 'auth_interceptor.dart';

/// Attendance service Dio instance that uses the same base URL and
/// [AuthInterceptor] as the auth [ApiClient].
class AttendanceApiClient {
  AttendanceApiClient._(TokenStorage tokenStorage, Dio authPlainDio)
      : dio = Dio(
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
        plainDio: authPlainDio,
        authenticatedDio: dio,
      ),
    );
  }

  static AttendanceApiClient? _instance;

  factory AttendanceApiClient(TokenStorage tokenStorage, Dio authPlainDio) {
    return _instance ??= AttendanceApiClient._(tokenStorage, authPlainDio);
  }

  final Dio dio;
}
