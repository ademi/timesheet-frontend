import 'package:dio/dio.dart';

import 'rate_limit.dart';

/// Waits [Retry-After] / `retry_after` on HTTP 429, then retries once.
///
/// Attach to authenticated Dio only. Login/refresh use [plainDio] and handle
/// 429 in their own call sites so we do not amplify auth storms.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({
    required Dio dio,
    this.maxRetries = 1,
  }) : _dio = dio;

  final Dio _dio;
  final int maxRetries;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 429) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    final attempt = (options.extra[kRateLimitRetriedExtra] as int?) ?? 0;
    if (attempt >= maxRetries) {
      return handler.next(err);
    }

    final delay = effectiveRateLimitDelay(
      rateLimitDelayFromResponse(err.response),
    );
    await Future<void>.delayed(delay);

    final retry = options.copyWith(
      extra: Map<String, dynamic>.from(options.extra)
        ..[kRateLimitRetriedExtra] = attempt + 1,
    );

    try {
      final response = await _dio.fetch(retry);
      return handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        return handler.reject(e);
      }
      return handler.reject(DioException(requestOptions: retry, error: e));
    }
  }
}
