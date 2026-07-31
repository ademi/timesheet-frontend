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
      expect(failure.presentation, AppFailurePresentation.billingGate);
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

    test('maps evidence_required to credential evidence guidance', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/contractor-me/credentials'),
          response: Response(
            requestOptions: RequestOptions(path: '/contractor-me/credentials'),
            statusCode: 422,
            data: {'detail': 'evidence_required'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.code, 'evidence_required');
      expect(
        failure.message,
        'Upload at least one evidence file before saving this credential.',
      );
      expect(failure.presentation, AppFailurePresentation.inline);
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

    test('maps registration invite failures to user messages', () {
      const expectedMessages = {
        'email_required_for_registration_invite':
            'An email address is required to send a registration invite.',
        'email_already_registered':
            'This email is already registered. Ask the contractor to log in.',
        'invite_token_invalid':
            'This registration invite is invalid or has expired.',
        'invite_email_mismatch':
            'Register using the email address that received this invite.',
      };

      for (final entry in expectedMessages.entries) {
        final failure = AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/x'),
            response: Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: 422,
              data: {'detail': entry.key},
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(failure.code, entry.key);
        expect(failure.message, entry.value);
      }
    });

    test('maps schedule leave and availability failures to user messages', () {
      const expectedMessages = {
        'leave_in_past':
            'Leave cannot end before today. Choose dates that are still current or in the future.',
        'availability_windows_overlap':
            'Availability windows on the same day cannot overlap.',
      };

      for (final entry in expectedMessages.entries) {
        final failure = AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/contractor-me/availability'),
            response: Response(
              requestOptions: RequestOptions(
                path: '/contractor-me/availability',
              ),
              statusCode: 400,
              data: {'detail': entry.key},
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(failure.code, entry.key);
        expect(failure.message, entry.value);
        expect(failure.presentation, AppFailurePresentation.inline);
      }
    });

    test('maps sharing authorisation failures to retry guidance', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/engagements/1/accept'),
          response: Response(
            requestOptions: RequestOptions(path: '/engagements/1/accept'),
            statusCode: 409,
            data: {'detail': 'sharing_authorisation_required'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.code, 'sharing_authorisation_required');
      expect(
        failure.message,
        'Could not record sharing authorisation. Try again or contact support.',
      );
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
