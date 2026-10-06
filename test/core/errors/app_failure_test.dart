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

    test('maps Missing permission before generic 403 forbidden', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/shifts'),
          response: Response(
            requestOptions: RequestOptions(path: '/shifts'),
            statusCode: 403,
            data: {'detail': 'Missing permission'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.code, 'missing_permission');
      expect(failure.message, 'You don’t have permission for this action.');
    });

    test('maps a forbidden document response to file-access guidance', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(
            path: '/documents/document-id/content',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/documents/document-id/content',
            ),
            statusCode: 403,
            data: {'detail': 'forbidden'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.code, 'forbidden');
      expect(failure.message, 'You don’t have access to this file.');
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
            'This email is already registered on another invite path.',
        'primary_site_already_exists':
            'This client already has a primary site. Refresh and try again.',
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

    test('maps sharing_grant_required from 403 detail string', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(
            path: '/tenants/current/contractors/c1/credentials',
          ),
          response: Response(
            requestOptions: RequestOptions(
              path: '/tenants/current/contractors/c1/credentials',
            ),
            statusCode: 403,
            data: {'detail': 'sharing_grant_required'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.code, 'sharing_grant_required');
      expect(failure.isSharingGrantRequired, isTrue);
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

    test('parses credential_gate_blocked gate.reasons', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/shifts/1/assign'),
          response: Response(
            requestOptions: RequestOptions(path: '/shifts/1/assign'),
            statusCode: 409,
            data: {
              'detail': {
                'code': 'credential_gate_blocked',
                'message': 'Worker credentials do not meet roster requirements.',
                'gate': {
                  'decision': 'block',
                  'reasons': [
                    {'category': 'wwcc', 'reason': 'expired'},
                  ],
                },
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.isCredentialGateBlocked, isTrue);
      expect(failure.eligibilityReasons, ['wwcc: expired']);
      expect(failure.message, contains('override'));
    });

    test('parses budget_burn_blocked burn hard_blocks', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/shifts/1/publish'),
          response: Response(
            requestOptions: RequestOptions(path: '/shifts/1/publish'),
            statusCode: 409,
            data: {
              'detail': {
                'code': 'budget_burn_blocked',
                'message': 'Publishing would exceed plan budget thresholds.',
                'burn': {
                  'hard_blocks': [
                    {
                      'participant_id': 'p1',
                      'client_id': 'c1',
                      'client_name': 'Maya',
                      'envelope': 'core',
                      'estimated_amount': 120,
                      'severity': 'hard_block',
                    },
                  ],
                  'soft_warns': [],
                  'by_participant': [],
                  'pace_outside_release': false,
                },
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );
      expect(failure.isBudgetBurnBlocked, isTrue);
      expect(failure.eligibilityReasons, contains('hard_block: Maya / core'));
      expect(failure.message, contains('budget'));
    });

    test('standing_job_exists is coordinator copy', () {
      expect(
        AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/jobs'),
            response: Response(
              requestOptions: RequestOptions(path: '/jobs'),
              statusCode: 409,
              data: {'detail': 'standing_job_exists'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        contains('already has ongoing support'),
      );
    });

    test('horizon_window_too_large is coordinator copy', () {
      expect(
        AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/jobs'),
            response: Response(
              requestOptions: RequestOptions(path: '/jobs'),
              statusCode: 422,
              data: {'detail': 'horizon_window_too_large'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        contains('14 days'),
      );
    });

    test('horizon_truncated is coordinator copy', () {
      expect(
        AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/jobs'),
            response: Response(
              requestOptions: RequestOptions(path: '/jobs'),
              statusCode: 422,
              data: {'detail': 'horizon_truncated'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        contains('Open roster again'),
      );
    });

    test('maps shift claim error codes', () {
      const expectedMessages = {
        'shift_full': 'This shift is already filled.',
        'invalid_shift_status':
            'This shift can’t be changed in its current state.',
        'contractor_on_leave': 'You’re on leave for this day.',
        'shift_not_found': 'Shift not found.',
        'shift_overlap':
            'A shift for this job already exists in that time window.',
      };

      for (final entry in expectedMessages.entries) {
        final failure = AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/shifts/x/claim'),
            response: Response(
              requestOptions: RequestOptions(path: '/shifts/x/claim'),
              statusCode: 409,
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
    test('maps visit_not_completed and invalid_engagement_state', () {
      expect(
        AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/payment-batches'),
            response: Response(
              requestOptions: RequestOptions(path: '/payment-batches'),
              statusCode: 400,
              data: {'detail': 'visit_not_completed'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        'Complete the visit before exporting or adding to a payment batch.',
      );
      expect(
        AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/payroll'),
            response: Response(
              requestOptions: RequestOptions(path: '/payroll'),
              statusCode: 409,
              data: {'detail': 'invalid_engagement_state'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ).message,
        'This worker is no longer in your workforce.',
      );
    });

    test('maps NDIS support item validation errors', () {
      const expectedMessages = {
        'support_item_pair': 'Enter both NDIS code and name, or clear both.',
        'support_item_code': 'Invalid NDIS item number format.',
        'support_item_not_in_catalogue':
            'Item not in the current NDIS catalogue.',
        'support_item_name_mismatch':
            'Name does not match the catalogue — pick from search.',
      };

      for (final entry in expectedMessages.entries) {
        final failure = AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/visits/v1/support-item'),
            response: Response(
              requestOptions: RequestOptions(path: '/visits/v1/support-item'),
              statusCode: 422,
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

    test('parses visit_errors from batch export responses', () {
      final failure = AppFailure.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/billing/invoice-exports'),
          response: Response(
            requestOptions: RequestOptions(path: '/billing/invoice-exports'),
            statusCode: 422,
            data: {
              'detail': {
                'code': 'batch_export_failed',
                'visit_errors': [
                  {
                    'visit_id': 'visit-1',
                    'code': 'visit_already_exported',
                    'message': 'Already exported.',
                  },
                ],
              },
            },
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.visitErrors, hasLength(1));
      expect(failure.visitErrors.single['visit_id'], 'visit-1');
      expect(failure.visitErrors.single['code'], 'visit_already_exported');
    });

    test('maps invoice export error codes', () {
      const expectedMessages = {
        'visit_already_exported':
            'Already included in an export — void that export to rebill.',
        'time_entry_not_closed':
            'Close the time entry before exporting this visit.',
        'support_item_required':
            'Choose a support item before publishing or generating shifts.',
        'contractor_already_assigned':
            'That worker is already assigned to this shift.',
        'visit_has_only_travel_claims':
            'This visit has travel claims but no hourly support item. Set an hourly item on the visit, then export — travel will be included automatically.',
        'visit_support_item_is_travel':
            'This visit’s support item is a travel (Each) item, not hourly. Set an hourly support item on the visit, and keep travel under Travel claims.',
        'visit_support_item_is_day_unit':
            'This visit’s support item is a day-rate item, not hourly. Set an hourly support item on the visit; add accommodation separately if needed.',
        'support_item_not_hourly':
            'Use an hourly (H) support item for visits. Travel and other non-hour items can’t be the visit support item.',
        'quote_required_not_exportable':
            'Quote-required items cannot be auto-exported.',
        'task_billable_minutes_required':
            'Set billable minutes on each billed task.',
        'task_minutes_exceed_visit_hours':
            'Task minutes exceed the visit duration.',
        'delivery_postcode_required':
            'Job location needs a postcode for pricing, or set a price tier override.',
        'price_limit_missing_for_tier':
            'That support item has no catalogue price for one of the '
            'pricing tiers (national / remote / very remote). '
            'Pick a different hourly support item on the Support step, '
            'or update the NDIS catalogue prices for this item.',
        'export_already_void': 'This export was already voided.',
        'export_not_voidable': 'Only finalized exports can be voided.',
        'travel_item_not_claimable':
            "That support item isn’t a travel claim item. Pick Provider travel – non-labour or Activity Based Transport from the list.",
        'travel_item_unit_not_exportable':
            'Travel claims must use a per-kilometre (Each) item, not an hourly one. Choose a travel item from the list.',
        'travel_equal_mixed_registration_groups':
            "These participants have different NDIS support types, so one shared travel item can’t be split equally. Switch to Nominated, or add a separate travel claim per support type.",
        'travel_registration_group_mismatch':
            'This travel item doesn’t match the participant’s support type (registration group). Pick the travel item that sits under the same support group as their visit support item — or change who the claim is nominated to.',
        'trip_kms_requires_rate_snapshots':
            'Publish the shift first so each participant has a support item. Trip kilometres need that to pick the matching travel claim item.',
        'trip_kms_travel_unresolvable':
            'No Provider travel / Activity Based Transport kilometre item exists in the catalogue for this support type. Import the current NDIS catalogue, or ask staff to add the travel claim with the correct item.',
        'labour_requires_rate_snapshots':
            'Publish the shift first so each participant has a rate snapshot. Worker travel time uses that hourly support item.',
        'labour_travel_not_permitted':
            'Provider Travel isn’t allowed for this support item in the catalogue. Choose a different support item on the visit, or use vehicle kilometres instead.',
        'labour_travel_unclaimed_exists':
            'This shift already has an unclaimed worker travel-time claim. Edit or claim that one first, or wait until it’s exported.',
        'labour_snapshot_item_not_hourly':
            'Worker travel time needs an hourly (H) support item on the participant’s rate snapshot. Update the published support item and try again.',
        'labour_snapshot_item_not_in_catalogue':
            'The participant’s published support item isn’t in the active catalogue. Re-publish the shift with a current catalogue item.',
      };

      for (final entry in expectedMessages.entries) {
        final failure = AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/billing/invoice-exports'),
            response: Response(
              requestOptions: RequestOptions(path: '/billing/invoice-exports'),
              statusCode: entry.key == 'export_already_void' ? 409 : 422,
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

    test('maps admin record-visit attendance codes', () {
      const expected = {
        'clock_times_in_future': (
          400,
          'Arrival and departure can’t be in the future.',
        ),
        'visit_already_completed': (
          409,
          'This visit is already completed.',
        ),
        'visit_cancelled': (
          409,
          'This visit was cancelled. Refresh and pick another visit.',
        ),
      };
      for (final entry in expected.entries) {
        final failure = AppFailure.fromDio(
          DioException(
            requestOptions: RequestOptions(path: '/attendance/adjustments'),
            response: Response(
              requestOptions: RequestOptions(path: '/attendance/adjustments'),
              statusCode: entry.value.$1,
              data: {'detail': entry.key},
            ),
            type: DioExceptionType.badResponse,
          ),
        );
        expect(failure.code, entry.key);
        expect(failure.message, entry.value.$2);
        expect(failure.presentation, AppFailurePresentation.inline);
      }
    });
  });
}
