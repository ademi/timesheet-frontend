import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/token_storage.dart';
import '../app_routes.dart';

/// Route guard that requires at least one of [requiredAny] JWT permissions.
///
/// Must be listed after [AuthGuard] (or alone when auth is already guaranteed).
/// Users without the required permission are sent to the admin hub (or gateway
/// if they have no access token).
class PermissionGuard extends GetMiddleware {
  PermissionGuard({required this.requiredAny});

  /// Caller needs any one of these permission keys (or `*` / platform.admin).
  final List<String> requiredAny;

  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<TokenStorage>()) {
      return const RouteSettings(name: AppRoutes.gateway);
    }
    final storage = Get.find<TokenStorage>();
    final token = storage.accessToken;
    if (token == null || token.isEmpty) {
      return const RouteSettings(name: AppRoutes.gateway);
    }
    if (storage.hasAnyPermission(requiredAny)) return null;
    return const RouteSettings(name: AppRoutes.adminPanel);
  }
}
