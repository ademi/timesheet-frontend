import 'package:dio/dio.dart';

import '../../app/data/models/auth/auth_error_model.dart';

/// How the UI should surface an [AppFailure].
enum AppFailurePresentation {
  screen,
  toast,
  inline,
  reLogin,
  billingGate,
}

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
    if (data is Map<String, dynamic>) {
      return AuthErrorModel.fromJson(data);
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
        return reasons.map((e) {
          if (e is Map) {
            final req = e['requirement'] ?? e['category'] ?? e['code'];
            final reason = e['reason'] ?? e['detail'] ?? e['code'];
            return '${req ?? 'requirement'}: ${reason ?? e}';
          }
          return e.toString();
        }).toList(growable: false);
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
      'engagement_not_active',
      'invalid_visit_status',
      'visit_overlap',
      'standing_job_exists',
      'contractor_not_found',
      'hard_split_violation',
      'engagement_already_exists',
      'payment_already_paid',
      'visit_already_in_batch',
      'visit_not_found',
    ];
    for (final k in known) {
      if (d == k || d.contains(k)) return k;
    }
    if (status == 402) return 'billing_gate';
    if (status == 429) return 'rate_limited';
    if (d.toLowerCase().contains('permission')) return 'missing_permission';
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
      case 'contractor_not_found':
      case 'visit_overlap':
        return AppFailurePresentation.inline;
      case 'proxy_required':
        return AppFailurePresentation.inline;
      case 'rate_limited':
        return AppFailurePresentation.toast;
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
      case 'counsel_pending':
        return 'This legal document is not available yet.';
      case 'engagement_not_active':
        return 'Engagement isn’t active. Contact your admin.';
      case 'invalid_visit_status':
        return 'Visit status changed. Refresh and try again.';
      case 'visit_overlap':
        return 'Overlapping visit — adjust the window or use partial generate.';
      case 'standing_job_exists':
        return 'An open standing job already exists for this client.';
      case 'contractor_not_found':
        return 'No contractor registered with that email/phone.';
      case 'hard_split_violation':
        return 'This user can’t be invited as a contractor.';
      case 'payment_already_paid':
        return 'Visit is already paid.';
      case 'visit_already_in_batch':
        return 'Visit is already in a payment batch.';
      case 'visit_not_found':
        return 'Visit not found.';
      case 'rate_limited':
        return 'Too many attempts — try again shortly.';
      default:
        return fallback;
    }
  }
}

/// Deprecated name — use [AppFailure].
typedef ApiFailure = AppFailure;
typedef ApiFailurePresentation = AppFailurePresentation;
