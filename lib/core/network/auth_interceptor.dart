import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../../app/data/datasources/remote/auth_remote_datasource.dart';
import '../../app/data/models/auth/auth_token_model.dart';
import '../../app/routes/app_routes.dart';
import '../constants/app_constants.dart';
import '../services/token_storage.dart';

/// Marks a request that already went through one 401 → refresh → retry cycle.
const String kAuth401RetriedExtra = 'auth_401_retried';

/// Attaches Bearer tokens, refreshes on 401 via [plainDio] (auth base URL),
/// and retries on [authenticatedDio].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage storage,
    required Dio plainDio,
    required Dio authenticatedDio,
  })  : _storage = storage,
        _plainDio = plainDio,
        _authenticatedDio = authenticatedDio;

  final TokenStorage _storage;
  final Dio _plainDio;
  final Dio _authenticatedDio;

  Future<void>? _refreshFuture;

  bool _isAuthRefreshPath(String path) => path.contains('/v1/auth/refresh');

  bool _isAuthLoginPath(String path) => path.contains('/v1/auth/login');

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

  void _redirectToLogin() {
    getx.Get.offAllNamed(AppRoutes.login);
  }

  Future<void> _refreshOrWait() async {
    if (_refreshFuture != null) {
      await _refreshFuture!;
      return;
    }
    final refreshToken = _storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/v1/auth/refresh',
          baseUrl: AppConstants.baseUrl,
        ),
        message: 'Missing refresh token',
      );
    }
    final future = () async {
      final tokens = await executeRefreshRequest(_plainDio, refreshToken);
      await _persistTokens(tokens);
    }();
    _refreshFuture = future;
    try {
      await future;
    } finally {
      _refreshFuture = null;
    }
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
    if (response?.statusCode != 401) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    if (options.extra[kAuth401RetriedExtra] == true) {
      await _clearTokens();
      _redirectToLogin();
      return handler.reject(err);
    }

    if (_isAuthRefreshPath(options.path)) {
      await _clearTokens();
      _redirectToLogin();
      return handler.reject(err);
    }

    if (_isAuthLoginPath(options.path)) {
      return handler.next(err);
    }

    try {
      await _refreshOrWait();
    } catch (_) {
      await _clearTokens();
      _redirectToLogin();
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
