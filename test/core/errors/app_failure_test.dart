import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rostiq/core/errors/app_failure.dart';

void main() {
  group('AppFailure.fromDio', () {
    test('maps 402 to billingGate', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 402,
            data: {'detail': 'require_active_subscription'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.isBillingGate, isTrue);
      expect(
        failure.presentation,
        AppFailurePresentation.billingGate,
      );
    });

    test('maps proxy_required', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 403,
            data: {'detail': 'proxy_required'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.isProxyRequired, isTrue);
    });

    test('maps 429', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 429,
            data: {'detail': 'rate_limited'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.code, 'rate_limited');
      expect(failure.presentation, AppFailurePresentation.toast);
    });

    test('parses eligibility reasons', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 409,
            data: {
              'detail': {
                'code': 'eligibility_incomplete',
                'reasons': [
                  {'requirement': 'credentials', 'reason': 'missing_wwcc'},
                ],
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.isEligibilityIncomplete, isTrue);
      expect(failure.eligibilityReasons, isNotEmpty);
    });
  });
}
