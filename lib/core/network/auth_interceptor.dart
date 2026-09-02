import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../../app/routes/app_routes.dart';
import '../auth/auth_session_invalidation.dart';
import '../services/token_refresh_service.dart';
import '../services/token_storage.dart';
import 'must_change_password.dart';

/// Marks a request that already went through one 401 → refresh → retry cycle.
const String kAuth401RetriedExtra = 'auth_401_retried';

/// Attaches Bearer tokens, refreshes on 401 via [TokenRefreshService],
/// and retries on [authenticatedDio].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required TokenRefreshService refreshService,
    required Dio authenticatedDio,
  })  : _storage = storage,
        _refreshService = refreshService,
        _authenticatedDio = authenticatedDio;

  final TokenStorage _storage;
  final TokenRefreshService _refreshService;
  final Dio _authenticatedDio;

  bool _isAuthRefreshPath(String path) => path.contains('/v1/auth/refresh');

  bool _isAuthLoginPath(String path) => path.contains('/v1/auth/login');

  Future<void> _invalidateSession() async {
    await invalidateStoredAuthSession();
  }

  void _redirectToLogin() {
    getx.Get.offAllNamed(AppRoutes.login);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final path = options.path;
    if (_isAuthLoginPath(path) || _isAuthRefreshPath(path)) {
      return handler.next(options);
    }
    final access = _storage.accessToken;
    if (access != null && access.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    if (dioErrorRequiresPasswordChange(err)) {
      redirectToFirstLoginIfNeeded();
      return handler.reject(err);
    }

    if (response?.statusCode != 401) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    if (options.extra[kAuth401RetriedExtra] == true) {
      await _invalidateSession();
      _redirectToLogin();
      return handler.reject(err);
    }

    if (_isAuthRefreshPath(options.path)) {
      await _invalidateSession();
      _redirectToLogin();
      return handler.reject(err);
    }

    if (_isAuthLoginPath(options.path)) {
      return handler.next(err);
    }

    final outcome = await _refreshService.refreshIfNeeded(force: true);
    switch (outcome) {
      case TokenRefreshOutcome.success:
      case TokenRefreshOutcome.notNeeded:
        break;
      case TokenRefreshOutcome.invalidRefreshToken:
        _redirectToLogin();
        return handler.reject(err);
      case TokenRefreshOutcome.transientFailure:
        return handler.reject(err);
    }

    final newAccess = _storage.accessToken;
    final retry = options.copyWith(
      headers: Map<String, dynamic>.from(options.headers)
        ..['Authorization'] = 'Bearer $newAccess',
      extra: Map<String, dynamic>.from(options.extra)
        ..[kAuth401RetriedExtra] = true,
    );

    try {
      final clone = await _authenticatedDio.fetch(retry);
      return handler.resolve(clone);
    } catch (e) {
      if (e is DioException) {
        return handler.reject(e);
      }
      return handler.reject(
        DioException(requestOptions: retry, error: e),
      );
    }
  }
}
