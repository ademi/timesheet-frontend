import 'package:dio/dio.dart';
import 'package:get/get.dart' as getx;

import '../../app/routes/app_routes.dart';

const String kMustChangePasswordDetail = 'must_change_password';

/// True when the API rejected the call because the user must set a new password.
bool isMustChangePasswordResponse(DioException err) {
  if (err.response?.statusCode != 403) return false;
  final data = err.response?.data;
  if (data is Map) {
    return data['detail'] == kMustChangePasswordDetail;
  }
  return false;
}

/// Alias used by [AuthInterceptor].
bool dioErrorRequiresPasswordChange(DioException err) =>
    isMustChangePasswordResponse(err);

/// Navigate to first-login when required. Keeps tokens so complete_first_login works.
void redirectToFirstLoginIfNeeded({bool mustChangePassword = true}) {
  if (!mustChangePassword) return;
  if (getx.Get.currentRoute == AppRoutes.firstLogin) return;
  getx.Get.offAllNamed(AppRoutes.firstLogin);
}
