import 'package:dio/dio.dart';

import '../../app/data/models/auth/auth_error_model.dart';

/// How the UI should surface an [AppFailure].
enum AppFailurePresentation { screen, toast, inline, reLogin, billingGate }

/// Typed API failure (Flutter restructure design §3.2 / §11).
class AppFailure implements Exception {
  const AppFailure({
    required this.code,
    required this.message,
    required this.presentation,
    this.statusCode,
    this.eligibilityReasons = const [],
  });

  final String code;
  final String message;
  final AppFailurePresentation presentation;
  final int? statusCode;

  /// Parsed from `eligibility_incomplete` payloads when present.
  final List<String> eligibilityReasons;

  bool get isBillingGate =>
      presentation == AppFailurePresentation.billingGate ||
      code == 'subscription_expired' ||
      code == 'require_active_subscription' ||
      code == 'billing_gate';

  bool get isProxyRequired => code == 'proxy_required';

  bool get isEligibilityIncomplete => code == 'eligibility_incomplete';

  bool get isSharingGrantRequired => code == 'sharing_grant_required';

  @override
  String toString() => message;

  static AppFailure fromDio(DioException e) {
    final status = e.response?.statusCode;
    final authErr = _tryAuthError(e);
    final detail = authErr?.detail ?? e.message ?? 'Something went wrong';
    final code = _normalizeCode(authErr?.code, detail, status);
    final reasons = _parseEligibilityReasons(e.response?.data);

    return AppFailure(
      code: code,
      message: _userMessage(code, detail),
      presentation: _presentationFor(code, status),
      statusCode: status,
      eligibilityReasons: reasons,
    );
  }

  static AuthErrorModel? _tryAuthError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final detail = map['detail'];
      // FastAPI validation list → first message
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          return AuthErrorModel(
            detail: first['msg']?.toString() ?? 'Validation failed',
            code: 'validation_error',
          );
        }
        return AuthErrorModel(
          detail: first.toString(),
          code: 'validation_error',
        );
      }
      return AuthErrorModel.fromJson(map);
    }
    return null;
  }

  static List<String> _parseEligibilityReasons(Object? data) {
    if (data is! Map) return const [];
    final map = Map<String, dynamic>.from(data);
    final detail = map['detail'];
    if (detail is Map) {
      final reasons = detail['reasons'] ?? detail['requirements'];
      if (reasons is List) {
        return reasons
            .map((e) {
              if (e is Map) {
                final req = e['requirement'] ?? e['category'] ?? e['code'];
                final reason = e['reason'] ?? e['detail'] ?? e['code'];
                return '${req ?? 'requirement'}: ${reason ?? e}';
              }
              return e.toString();
            })
            .toList(growable: false);
      }
    }
    return const [];
  }

  static String _normalizeCode(String? explicit, String detail, int? status) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final d = detail.trim();
    const known = [
      'wrong_actor_type',
      'must_change_password',
      'missing_permission',
      'forbidden',
      'subscription_expired',
      'require_active_subscription',
      'geofence_rejected',
      'forms_incomplete',
      'required_forms_incomplete',
      'docs_incomplete',
      'scan_blocked',
      'proxy_required',
      'eligibility_incomplete',
      'counsel_pending',
      'counsel_pending_policy',
      'legal_document_unavailable',
      'engagement_not_active',
      'invalid_visit_status',
      'visit_overlap',
      'shift_overlap',
      'site_or_branch_required',
      'standing_job_exists',
      'horizon_window_too_large',
      'horizon_truncated',
      'split_blocked_by_active_visit',
      'contractor_not_found',
      'hard_split_violation',
      'email_required_for_registration_invite',
      'email_already_registered',
      'invite_token_invalid',
      'invite_email_mismatch',
      'engagement_already_exists',
      'payment_already_paid',
      'visit_already_in_batch',
      'visit_not_found',
      'mfa_required',
      'notice_not_presented',
      'consent_required',
      'invalid_category',
      'sharing_authorisation_required',
      'sharing_authorisation_forbidden',
      'sharing_grant_required',
      'invalid_transition',
      'invalid_engagement_state',
      'visit_not_completed',
      'hard_split_violation',
      'leave_in_past',
      'availability_windows_overlap',
      'credential_id_required',
      'evidence_required',
      'shift_full',
      'invalid_shift_status',
      'contractor_on_leave',
      'shift_not_found',
      'shift_overlap',
      'support_item_pair',
      'support_item_not_in_catalogue',
      'support_item_name_mismatch',
      'support_item_code',
      'support_item_not_hourly',
      'support_item_required',
      'quote_required_not_exportable',
      'visit_already_exported',
      'time_entry_not_closed',
      'task_billable_minutes_required',
      'task_minutes_exceed_visit_hours',
      'delivery_postcode_required',
      'price_limit_missing_for_tier',
      'export_already_void',
      'export_not_voidable',
    ];
    for (final k in known) {
      if (d == k || d.contains(k)) return k;
    }
    if (d.toLowerCase().contains('permission')) return 'missing_permission';
    if (status == 403) return 'forbidden';
    if (status == 402) return 'billing_gate';
    if (status == 429) return 'rate_limited';
    if (d.toLowerCase().contains('subscription')) {
      return 'require_active_subscription';
    }
    return 'unknown';
  }

  static AppFailurePresentation _presentationFor(String code, int? status) {
    switch (code) {
      case 'wrong_actor_type':
      case 'hard_split_violation':
      case 'must_change_password':
      case 'counsel_pending':
      case 'counsel_pending_policy':
        return AppFailurePresentation.screen;
      case 'subscription_expired':
      case 'require_active_subscription':
      case 'billing_gate':
        return AppFailurePresentation.billingGate;
      case 'eligibility_incomplete':
      case 'geofence_rejected':
      case 'forms_incomplete':
      case 'required_forms_incomplete':
      case 'docs_incomplete':
      case 'scan_blocked':
      case 'standing_job_exists':
      case 'horizon_window_too_large':
      case 'horizon_truncated':
      case 'split_blocked_by_active_visit':
      case 'contractor_not_found':
      case 'visit_overlap':
      case 'shift_overlap':
      case 'site_or_branch_required':
      case 'leave_in_past':
      case 'availability_windows_overlap':
      case 'evidence_required':
      case 'shift_full':
      case 'invalid_shift_status':
      case 'contractor_on_leave':
      case 'shift_not_found':
      case 'support_item_pair':
      case 'support_item_code':
      case 'support_item_not_in_catalogue':
      case 'support_item_name_mismatch':
      case 'support_item_required':
      case 'support_item_not_hourly':
      case 'quote_required_not_exportable':
      case 'visit_already_exported':
      case 'time_entry_not_closed':
      case 'task_billable_minutes_required':
      case 'task_minutes_exceed_visit_hours':
      case 'delivery_postcode_required':
      case 'price_limit_missing_for_tier':
      case 'export_already_void':
      case 'export_not_voidable':
        return AppFailurePresentation.inline;
      case 'proxy_required':
        return AppFailurePresentation.inline;
      case 'sharing_grant_required':
        return AppFailurePresentation.inline;
      case 'rate_limited':
        return AppFailurePresentation.toast;
      case 'mfa_required':
        return AppFailurePresentation.screen;
      default:
        if (status == 401) return AppFailurePresentation.reLogin;
        if (status == 402) return AppFailurePresentation.billingGate;
        if (status == 429) return AppFailurePresentation.toast;
        return AppFailurePresentation.toast;
    }
  }

  static String _userMessage(String code, String fallback) {
    switch (code) {
      case 'wrong_actor_type':
        return 'This account can’t use this area. Sign in with the correct account type.';
      case 'must_change_password':
        return 'You must set a new password before continuing.';
      case 'missing_permission':
        return 'You don’t have permission for this action.';
      case 'forbidden':
        return 'You don’t have access to this file.';
      case 'subscription_expired':
      case 'require_active_subscription':
      case 'billing_gate':
        return 'Subscription inactive — renew on the billing page.';
      case 'geofence_rejected':
        return 'You’re outside the allowed area. Move closer and try again.';
      case 'forms_incomplete':
      case 'required_forms_incomplete':
        return 'Complete required forms before finishing the visit.';
      case 'docs_incomplete':
        return 'Upload required documents before approval.';
      case 'scan_blocked':
        return 'File failed security scan. Re-upload a clean file.';
      case 'proxy_required':
        return 'This file must be opened through a secure download.';
      case 'eligibility_incomplete':
        return 'Requirements incomplete — review the listed items.';
      case 'mfa_required':
        return 'Multi-factor authentication required. Complete MFA, then retry.';
      case 'notice_not_presented':
        return 'Collection notice must be presented before creating this credential.';
      case 'consent_required':
        return 'Consent is required for this sensitive credential type.';
      case 'invalid_category':
        return 'That credential type is not allowed.';
      case 'sharing_authorisation_required':
      case 'sharing_authorisation_forbidden':
        return 'Could not record sharing authorisation. Try again or contact support.';
      case 'sharing_grant_required':
        return 'This contractor has not shared credentials with your organisation yet.';
      case 'invalid_transition':
        return 'This action isn’t available for the engagement’s current '
            'status. If documents are still pending, review credentials '
            'first, then try again.';
      case 'invalid_engagement_state':
        return 'This worker is no longer in your workforce.';
      case 'visit_not_completed':
        return 'Complete the visit before exporting or adding to a payment batch.';
      case 'counsel_pending':
      case 'counsel_pending_policy':
      case 'legal_document_unavailable':
        return 'This legal document is not available yet.';
      case 'engagement_not_active':
        return 'Engagement isn’t active. Contact your admin.';
      case 'invalid_visit_status':
        return 'Cannot change this visit in its current status. Refresh and try again.';
      case 'visit_overlap':
        return 'Overlapping visit — adjust the window or use partial generate.';
      case 'shift_overlap':
        return 'A shift for this job already exists in that time window.';
      case 'leave_in_past':
        return 'Leave cannot end before today. Choose dates that are still current or in the future.';
      case 'availability_windows_overlap':
        return 'Availability windows on the same day cannot overlap.';
      case 'credential_id_required':
        return 'Select a credential to view access history.';
      case 'evidence_required':
        return 'Upload at least one evidence file before saving this credential.';
      case 'site_or_branch_required':
        return 'Add a site or branch for this client before booking support.';
      case 'standing_job_exists':
        return 'This client already has ongoing support. Open it, or book one extra session.';
      case 'horizon_window_too_large':
        return 'Choose a window of 14 days or less.';
      case 'horizon_truncated':
        return 'Filled as many upcoming shifts as allowed. Open roster again to continue.';
      case 'split_blocked_by_active_visit':
        return 'Can’t change this pattern — a future visit is already in progress or completed.';
      case 'contractor_not_found':
        return 'No contractor registered with that email/phone.';
      case 'hard_split_violation':
        return 'This user can’t be invited as a contractor.';
      case 'email_required_for_registration_invite':
        return 'An email address is required to send a registration invite.';
      case 'email_already_registered':
        return 'This email is already registered. Ask the contractor to log in.';
      case 'invite_token_invalid':
        return 'This registration invite is invalid or has expired.';
      case 'invite_email_mismatch':
        return 'Register using the email address that received this invite.';
      case 'payment_already_paid':
        return 'Visit is already paid.';
      case 'visit_already_in_batch':
        return 'Visit is already in a payment batch.';
      case 'visit_not_found':
        return 'Visit not found.';
      case 'rate_limited':
        return 'Too many attempts — try again shortly.';
      case 'shift_full':
        return 'This shift is already filled.';
      case 'invalid_shift_status':
        return 'This shift can’t be changed in its current state.';
      case 'contractor_on_leave':
        return 'You’re on leave for this day.';
      case 'shift_not_found':
        return 'Shift not found.';
      case 'support_item_pair':
        return 'Enter both NDIS code and name, or clear both.';
      case 'support_item_code':
        return 'Invalid NDIS item number format.';
      case 'support_item_not_in_catalogue':
        return 'Item not in the current NDIS catalogue.';
      case 'support_item_name_mismatch':
        return 'Name does not match the catalogue — pick from search.';
      case 'support_item_required':
        return 'Set a support item on the visit before exporting.';
      case 'support_item_not_hourly':
        return 'Only hourly (H) support items can be exported.';
      case 'quote_required_not_exportable':
        return 'Quote-required items cannot be auto-exported.';
      case 'visit_already_exported':
        return 'Already included in an export — void that export to rebill.';
      case 'time_entry_not_closed':
        return 'Close the time entry before exporting this visit.';
      case 'task_billable_minutes_required':
        return 'Set billable minutes on each billed task.';
      case 'task_minutes_exceed_visit_hours':
        return 'Task minutes exceed the visit duration.';
      case 'delivery_postcode_required':
        return 'Job location needs a postcode for pricing, or set a price tier override.';
      case 'price_limit_missing_for_tier':
        return 'The catalogue has no price for this pricing tier.';
      case 'export_already_void':
        return 'This export was already voided.';
      case 'export_not_voidable':
        return 'Only finalized exports can be voided.';
      default:
        return fallback;
    }
  }
}

/// Deprecated name — use [AppFailure].
typedef ApiFailure = AppFailure;
typedef ApiFailurePresentation = AppFailurePresentation;
