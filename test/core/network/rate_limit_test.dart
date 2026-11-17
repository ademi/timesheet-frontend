import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/network/rate_limit.dart';

void main() {
  group('rateLimitDelayFromResponse', () {
    test('prefers Retry-After header seconds', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/v1/x'),
        statusCode: 429,
        headers: Headers.fromMap({
          'retry-after': ['12'],
        }),
        data: {'retry_after': 99},
      );

      expect(
        rateLimitDelayFromResponse(response),
        const Duration(seconds: 12),
      );
    });

    test('reads public body retry_after', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/v1/auth/login'),
        statusCode: 429,
        data: {'message': 'Rate limit exceeded', 'retry_after': 7},
      );

      expect(
        rateLimitDelayFromResponse(response),
        const Duration(seconds: 7),
      );
    });

    test('reads authenticated body retry_after', () {
      final response = Response(
        requestOptions: RequestOptions(path: '/v1/visits'),
        statusCode: 429,
        data: {
          'error': 'Too many requests',
          'code': 'rate_limit_exceeded',
          'retry_after': 3,
        },
      );

      expect(
        rateLimitDelayFromResponse(response),
        const Duration(seconds: 3),
      );
    });
  });

  group('effectiveRateLimitDelay', () {
    test('falls back and caps', () {
      expect(
        effectiveRateLimitDelay(null),
        kDefaultRateLimitDelay,
      );
      expect(
        effectiveRateLimitDelay(const Duration(seconds: 120)),
        kMaxAutoRateLimitDelay,
      );
      expect(
        effectiveRateLimitDelay(Duration.zero),
        Duration.zero,
      );
      expect(
        effectiveRateLimitDelay(const Duration(seconds: -1)),
        kDefaultRateLimitDelay,
      );
    });
  });
}
