import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth/auth_token_model.dart';
import '../models/auth/login_request_model.dart';
import '../models/auth/logout_request_model.dart';
import '../models/auth/set_pin_request_model.dart';
import '../models/auth/verify_pin_request_model.dart';
import '../models/auth/verify_pin_response_model.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required GetStorage storage,
  }) : _remote = remote,
       _storage = storage;

  final AuthRemoteDataSource _remote;
  final GetStorage _storage;

  Future<VerifyPinResponseModel> verifyPin(String email, String pin) async {
    try {
      return await _remote.verifyPin(
        VerifyPinRequestModel(email: email, pin: pin),
      );
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<void> setPin({
    required String email,
    required String pin,
    required String confirmPin,
  }) async {
    try {
      await _remote.setPin(
        SetPinRequestModel(
          email: email,
          pin: pin,
          confirmPin: confirmPin,
        ),
      );
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final tokens = await _remote.login(
        LoginRequestModel(
          email: email,
          password: password,
          tenantId: AppConstants.tenantId,
        ),
      );
      await _persistTokens(tokens);
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<void> logout() async {
    final refresh = _storage.read<String>(StorageKeys.refreshToken);
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _remote.logout(LogoutRequestModel(refreshToken: refresh));
      }
    } on DioException catch (_) {
      // Spec: still clear tokens on API error.
    } catch (_) {
      // Ignore non-Dio errors; always clear locally.
    } finally {
      _clearTokens();
    }
  }

  Future<void> _persistTokens(AuthTokenModel tokens) async {
    await _storage.write(StorageKeys.accessToken, tokens.accessToken);
    await _storage.write(StorageKeys.refreshToken, tokens.refreshToken);
  }

  void _clearTokens() {
    _storage.remove(StorageKeys.accessToken);
    _storage.remove(StorageKeys.refreshToken);
  }
}
