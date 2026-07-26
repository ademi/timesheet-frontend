import 'package:dio/dio.dart';

import '../../../core/services/token_storage.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../models/auth/auth_token_model.dart';
import '../models/auth/first_login_request_model.dart';
import '../models/auth/login_request_model.dart';
import '../models/auth/logout_request_model.dart';
import '../models/auth/me_context_model.dart';
import '../models/auth/switch_tenant_request_model.dart';

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required TokenStorage storage,
  })  : _remote = remote,
        _storage = storage;

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  Future<AuthTokenModel> loginWithTokens(String identifier, String password) async {
    try {
      final tokens = await _remote.login(
        LoginRequestModel(
          identifier: identifier,
          password: password,
        ),
      );
      await _persistTokens(tokens);
      return tokens;
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<AuthTokenModel> switchTenant(String tenantId) async {
    try {
      final tokens = await _remote.switchTenant(
        SwitchTenantRequestModel(tenantId: tenantId),
      );
      await _persistTokens(tokens);
      return tokens;
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<MeContextModel> getMeContext() {
    return _remote.getMeContext();
  }

  Future<void> completeFirstLogin(String newPassword) async {
    try {
      await _remote.completeFirstLogin(
        FirstLoginRequestModel(newPassword: newPassword),
      );
      await _storage.clear();
    } on DioException catch (e) {
      final authErr = parseAuthError(e);
      if (authErr != null) throw authErr;
      rethrow;
    }
  }

  Future<void> logout() async {
    final refresh = _storage.refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _remote.logout(LogoutRequestModel(refreshToken: refresh));
      }
    } on DioException catch (_) {
      // Spec: still clear tokens on API error.
    } catch (_) {
      // Ignore non-Dio errors; always clear locally.
    } finally {
      await _clearTokens();
    }
  }

  Future<void> _persistTokens(AuthTokenModel tokens) async {
    await _storage.persist(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      branchId: tokens.defaultBranchId,
    );
  }

  Future<void> _clearTokens() async {
    await _storage.clear();
  }
}
