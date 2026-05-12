import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/app_constants.dart';
import 'auth_interceptor.dart';

/// Auth [ApiClient]: [plainDio] for unauthenticated auth calls (`/v1/auth/login`, `/v1/auth/refresh`);
/// [dio] for authenticated auth calls (Bearer from [AuthInterceptor], e.g. `/v1/auth/logout`, `/v1/auth/change_password`).
class ApiClient {
  ApiClient._(GetStorage storage)
      : plainDio = Dio(
          BaseOptions(
            baseUrl: AppConstants.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
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
        plainDio: plainDio,
        authenticatedDio: dio,
      ),
    );
  }

  static ApiClient? _instance;

  factory ApiClient(GetStorage storage) {
    return _instance ??= ApiClient._(storage);
  }

  final Dio plainDio;
  final Dio dio;
}
