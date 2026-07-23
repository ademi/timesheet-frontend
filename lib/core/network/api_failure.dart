import 'package:dio/dio.dart';

import '../../app/data/models/auth/auth_error_model.dart';

/// How the UI should surface an [ApiFailure].
enum ApiFailurePresentation {
  /// Dedicated full-screen / blocking route.
  screen,

  /// Snackbar / inline toast.
  toast,

  /// Inline field or section message.
  inline,

  /// Clear session and return to login.
  reLogin,
}

/// Typed API failure mapped from Dio / `detail` codes (wiring guide §18).
class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    required this.presentation,
    this.statusCode,
  });

  /// Normalized code (e.g. `wrong_actor_type`, `geofence_rejected`).
  final String code;
  final String message;
  final ApiFailurePresentation presentation;
  final int? statusCode;

  @override
  String toString() => message;

  static ApiFailure fromDio(DioException e) {
    final status = e.response?.statusCode;
    final authErr = _tryAuthError(e);
    final detail = authErr?.detail ?? e.message ?? 'Something went wrong';
    final code = _normalizeCode(authErr?.code, detail);

    return ApiFailure(
      code: code,
      message: _userMessage(code, detail),
      presentation: _presentationFor(code, status),
      statusCode: status,
    );
  }

  static AuthErrorModel? _tryAuthError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return AuthErrorModel.fromJson(data);
    }
    return null;
  }

  static String _normalizeCode(String? explicit, String detail) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final d = detail.trim();
    const known = [
      'wrong_actor_type',
      'must_change_password',
      'missing_permission',
      'subscription_expired',
      'geofence_rejected',
      'forms_incomplete',
      'required_forms_incomplete',
      'docs_incomplete',
      'scan_blocked',
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
    if (d.toLowerCase().contains('permission')) return 'missing_permission';
    return 'unknown';
  }

  static ApiFailurePresentation _presentationFor(String code, int? status) {
    switch (code) {
      case 'wrong_actor_type':
      case 'hard_split_violation':
        return ApiFailurePresentation.screen;
      case 'must_change_password':
        return ApiFailurePresentation.screen;
      case 'subscription_expired':
        return ApiFailurePresentation.screen;
      case 'geofence_rejected':
      case 'forms_incomplete':
      case 'required_forms_incomplete':
      case 'docs_incomplete':
      case 'scan_blocked':
      case 'standing_job_exists':
      case 'contractor_not_found':
      case 'visit_overlap':
        return ApiFailurePresentation.inline;
      default:
        if (status == 401) return ApiFailurePresentation.reLogin;
        return ApiFailurePresentation.toast;
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
        return 'Subscription expired — renew on the website.';
      case 'geofence_rejected':
        return 'You’re outside the allowed area. Move closer and try again.';
      case 'forms_incomplete':
      case 'required_forms_incomplete':
        return 'Complete required forms before finishing the visit.';
      case 'docs_incomplete':
        return 'Upload required documents before approval.';
      case 'scan_blocked':
        return 'File failed security scan. Re-upload a clean file.';
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
      default:
        return fallback;
    }
  }
}
