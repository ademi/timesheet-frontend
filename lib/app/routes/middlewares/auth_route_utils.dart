import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/token_storage.dart';
import '../app_routes.dart';

/// Redirects to gateway only when there are no credentials to recover with.
///
/// Expired or missing access tokens are allowed through when a refresh token
/// exists; [AuthInterceptor] refreshes on the next API 401.
RouteSettings? redirectWhenUnauthenticated() {
  if (!Get.isRegistered<TokenStorage>()) {
    return const RouteSettings(name: AppRoutes.gateway);
  }
  if (!Get.find<TokenStorage>().canAttemptAuth) {
    return const RouteSettings(name: AppRoutes.gateway);
  }
  return null;
}
