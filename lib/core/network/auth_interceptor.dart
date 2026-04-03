import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;
import 'package:get_storage/get_storage.dart';

import '../../app/data/datasources/remote/auth_remote_datasource.dart';
import '../../app/data/models/auth/auth_token_model.dart';
import '../../app/routes/app_routes.dart';
import '../constants/app_constants.dart';

/// Marks a request that already went through one 401 → refresh → retry cycle.
const String kAuth401RetriedExtra = 'auth_401_retried';

/// Attaches Bearer tokens, refreshes on 401 via [plainDio] (auth base URL),
/// and retries on [authenticatedDio].
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required GetStorage storage,
    required Dio plainDio,
    required Dio authenticatedDio,
  })  : _storage = storage,
        _plainDio = plainDio,
        _authenticatedDio = authenticatedDio;

  final GetStorage _storage;
  final Dio _plainDio;
  final Dio _authenticatedDio;

  Future<void>? _refreshFuture;

  bool _isAuthRefreshPath(String path) => path.contains('/auth/refresh');

  bool _isAuthLoginPath(String path) => path.contains('/auth/login');

  Future<void> _persistTokens(AuthTokenModel tokens) async {
    await _storage.write(StorageKeys.accessToken, tokens.accessToken);
    await _storage.write(StorageKeys.refreshToken, tokens.refreshToken);
  }

  void _clearTokens() {
    _storage.remove(StorageKeys.accessToken);
    _storage.remove(StorageKeys.refreshToken);
  }

  void _redirectToLogin() {
    getx.Get.offAllNamed(AppRoutes.login);
  }

  Future<void> _refreshOrWait() async {
    if (_refreshFuture != null) {
      await _refreshFuture!;
      return;
    }
    final refreshToken = _storage.read<String>(StorageKeys.refreshToken);
    if (refreshToken == null || refreshToken.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(
          path: '/auth/refresh',
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
    final access = _storage.read<String>(StorageKeys.accessToken);
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
      _clearTokens();
      _redirectToLogin();
      return handler.reject(err);
    }

    if (_isAuthRefreshPath(options.path)) {
      _clearTokens();
      _redirectToLogin();
      return handler.reject(err);
    }

    if (_isAuthLoginPath(options.path)) {
      return handler.next(err);
    }

    try {
      await _refreshOrWait();
    } catch (_) {
      _clearTokens();
      _redirectToLogin();
      return handler.reject(err);
    }

    final newAccess = _storage.read<String>(StorageKeys.accessToken);
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
