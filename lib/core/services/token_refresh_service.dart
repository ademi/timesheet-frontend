import 'package:dio/dio.dart';

import '../auth/auth_session_invalidation.dart';
import '../../app/data/datasources/remote/auth_remote_datasource.dart';
import '../network/must_change_password.dart';
import 'token_storage.dart';

enum TokenRefreshOutcome {
  /// Access token is still valid; no refresh was attempted.
  notNeeded,

  /// Refresh succeeded and a new access token was stored.
  success,

  /// Refresh token is missing, rejected, or expired.
  invalidRefreshToken,

  /// Refresh could not complete (e.g. network); tokens were left intact.
  transientFailure,
}

/// Shared silent refresh used on app start, resume, gateway restore, and 401 retry.
class TokenRefreshService {
  TokenRefreshService({
    required TokenStorage storage,
    required Dio plainDio,
  })  : _storage = storage,
        _plainDio = plainDio;

  final TokenStorage _storage;
  final Dio _plainDio;

  Future<TokenRefreshOutcome>? _refreshFuture;

  /// Refreshes when the access token is missing or expired.
  ///
  /// When [force] is true, attempts refresh even if the access token still
  /// decodes as valid (used after a 401 from the API).
  Future<TokenRefreshOutcome> refreshIfNeeded({bool force = false}) async {
    if (!force && _storage.hasValidAccessToken) {
      return TokenRefreshOutcome.notNeeded;
    }

    final refreshToken = _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return TokenRefreshOutcome.invalidRefreshToken;
    }

    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    final future = _executeRefresh(refreshToken);
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<TokenRefreshOutcome> _executeRefresh(String refreshToken) async {
    try {
      final tokens = await executeRefreshRequest(_plainDio, refreshToken);
      await _storage.persistTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      redirectToFirstLoginIfNeeded(
        mustChangePassword: tokens.mustChangePassword,
      );
      return TokenRefreshOutcome.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await invalidateStoredAuthSession(tokenStorage: _storage);
        return TokenRefreshOutcome.invalidRefreshToken;
      }
      return TokenRefreshOutcome.transientFailure;
    } catch (_) {
      return TokenRefreshOutcome.transientFailure;
    }
  }
}
