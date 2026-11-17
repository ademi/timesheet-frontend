import 'package:dio/dio.dart';

import '../auth/auth_session_invalidation.dart';
import '../../app/data/datasources/remote/auth_remote_datasource.dart';
import '../../app/data/models/auth/auth_token_model.dart';
import '../network/must_change_password.dart';
import '../network/rate_limit.dart';
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
  TokenRefreshService({required TokenStorage storage, required Dio plainDio})
    : _storage = storage,
      _plainDio = plainDio;

  final TokenStorage _storage;
  final Dio _plainDio;

  Future<TokenRefreshOutcome>? _refreshFuture;

  /// Soft cooldown after a 429 so callers do not immediately re-hit refresh.
  DateTime? _rateLimitedUntil;

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

    final until = _rateLimitedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      return TokenRefreshOutcome.transientFailure;
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
      return await _persistRefreshResult(
        refreshToken: refreshToken,
        tokens: await executeRefreshRequest(_plainDio, refreshToken),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (_storage.refreshToken != refreshToken) {
          return _storage.hasRefreshToken
              ? TokenRefreshOutcome.notNeeded
              : TokenRefreshOutcome.invalidRefreshToken;
        }
        await invalidateStoredAuthSession(tokenStorage: _storage);
        return TokenRefreshOutcome.invalidRefreshToken;
      }
      if (e.response?.statusCode == 429) {
        return _retryRefreshAfterRateLimit(refreshToken, e.response);
      }
      return TokenRefreshOutcome.transientFailure;
    } catch (_) {
      return TokenRefreshOutcome.transientFailure;
    }
  }

  Future<TokenRefreshOutcome> _retryRefreshAfterRateLimit(
    String refreshToken,
    Response? response,
  ) async {
    final delay = effectiveRateLimitDelay(
      rateLimitDelayFromResponse(response),
    );
    _rateLimitedUntil = DateTime.now().add(delay);
    await Future<void>.delayed(delay);

    if (_storage.refreshToken != refreshToken) {
      return _storage.hasRefreshToken
          ? TokenRefreshOutcome.notNeeded
          : TokenRefreshOutcome.invalidRefreshToken;
    }

    try {
      final tokens = await executeRefreshRequest(_plainDio, refreshToken);
      _rateLimitedUntil = null;
      return _persistRefreshResult(
        refreshToken: refreshToken,
        tokens: tokens,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (_storage.refreshToken != refreshToken) {
          return _storage.hasRefreshToken
              ? TokenRefreshOutcome.notNeeded
              : TokenRefreshOutcome.invalidRefreshToken;
        }
        await invalidateStoredAuthSession(tokenStorage: _storage);
        return TokenRefreshOutcome.invalidRefreshToken;
      }
      if (e.response?.statusCode == 429) {
        final again = effectiveRateLimitDelay(
          rateLimitDelayFromResponse(e.response),
        );
        _rateLimitedUntil = DateTime.now().add(again);
      }
      return TokenRefreshOutcome.transientFailure;
    } catch (_) {
      return TokenRefreshOutcome.transientFailure;
    }
  }

  Future<TokenRefreshOutcome> _persistRefreshResult({
    required String refreshToken,
    required AuthTokenModel tokens,
  }) async {
    // Logout / login / switch-tenant may have replaced the session while
    // this refresh was in flight. Never write the old tenant back.
    if (_storage.refreshToken != refreshToken) {
      return _storage.hasRefreshToken
          ? TokenRefreshOutcome.notNeeded
          : TokenRefreshOutcome.invalidRefreshToken;
    }
    final wrote = await _storage.persistTokensIfCurrentRefresh(
      expectedRefreshToken: refreshToken,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    if (!wrote) {
      return _storage.hasRefreshToken
          ? TokenRefreshOutcome.notNeeded
          : TokenRefreshOutcome.invalidRefreshToken;
    }
    redirectToFirstLoginIfNeeded(
      mustChangePassword: tokens.mustChangePassword,
    );
    return TokenRefreshOutcome.success;
  }
}
