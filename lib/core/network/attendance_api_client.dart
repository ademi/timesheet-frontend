import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/app_constants.dart';
import 'auth_interceptor.dart';

/// Attendance service Dio instance that uses the same base URL and
/// [AuthInterceptor] as the auth [ApiClient].
class AttendanceApiClient {
  AttendanceApiClient._(GetStorage storage, Dio authPlainDio)
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: const {
              Headers.contentTypeHeader: Headers.jsonContentType,
              Headers.acceptHeader: Headers.jsonContentType,
            },
          ),
        ) {
    dio.interceptors.add(
      AuthInterceptor(
        storage: storage,
        plainDio: authPlainDio,
        authenticatedDio: dio,
      ),
    );
  }

  static AttendanceApiClient? _instance;

  factory AttendanceApiClient(GetStorage storage, Dio authPlainDio) {
    return _instance ??= AttendanceApiClient._(storage, authPlainDio);
  }

  final Dio dio;
}
