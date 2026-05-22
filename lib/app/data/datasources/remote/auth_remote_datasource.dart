import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../models/auth/auth_error_model.dart';
import '../../models/auth/auth_token_model.dart';
import '../../models/auth/change_password_request_model.dart';
import '../../models/auth/login_request_model.dart';
import '../../models/auth/logout_request_model.dart';
import '../../models/auth/logout_response_model.dart';
import '../../models/auth/refresh_request_model.dart';
import '../../models/auth/verify_user_request_model.dart';
import '../../models/auth/verify_user_response_model.dart';

/// Shared refresh call used by [AuthInterceptor] and [AuthRemoteDataSource].
Future<AuthTokenModel> executeRefreshRequest(
  Dio plainDio,
  String refreshToken,
) async {
  final response = await plainDio.post<Map<String, dynamic>>(
    '/v1/auth/refresh',
    data: RefreshRequestModel(refreshToken: refreshToken).toJson(),
  );
  final data = response.data;
  if (data == null) {
    throw DioException(
      requestOptions: response.requestOptions,
      message: 'Empty refresh response',
    );
  }
  return AuthTokenModel.fromJson(data);
}

class AuthRemoteDataSource {
  AuthRemoteDataSource({required Dio plainDio, required Dio authenticatedDio})
    : _plainDio = plainDio,
      _authenticatedDio = authenticatedDio;

  final Dio _plainDio;
  final Dio _authenticatedDio;

  Future<VerifyUserResponseModel> verifyUser(
    VerifyUserRequestModel request,
  ) async {
    final response = await _plainDio.post<Map<String, dynamic>>(
      AppConstants.verifyUserPath,
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty verify user response',
      );
    }
    return VerifyUserResponseModel.fromJson(data);
  }

  Future<AuthTokenModel> login(LoginRequestModel request) async {
    try {
      final response = await _plainDio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: request.toJson(),
      );
      final data = response.data;
      if (data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          message: 'Empty login response',
        );
      }
      return AuthTokenModel.fromJson(data);
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<AuthTokenModel> refresh(RefreshRequestModel request) {
    return executeRefreshRequest(_plainDio, request.refreshToken);
  }

  Future<LogoutResponseModel> logout(LogoutRequestModel request) async {
    final response = await _authenticatedDio.post<Map<String, dynamic>>(
      '/v1/auth/logout',
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty logout response',
      );
    }
    return LogoutResponseModel.fromJson(data);
  }

  /// Calls POST /v1/auth/change_password (requires Bearer access token).
  Future<String> changePassword(ChangePasswordRequestModel request) async {
    final response = await _authenticatedDio.post<Map<String, dynamic>>(
      '/v1/auth/set_initial_password',
      data: request.toJson(),
    );
    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Empty change password response',
      );
    }
    return data['message'] as String? ?? 'ok';
  }
}

/// Parses [DioException.response] into [AuthErrorModel] when possible.
AuthErrorModel? parseAuthError(DioException e) {
  final data = e.response?.data;
  if (data is Map<String, dynamic>) {
    return AuthErrorModel.fromJson(data);
  }
  return null;
}
