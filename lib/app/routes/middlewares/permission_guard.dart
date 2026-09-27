import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import 'auth_route_utils.dart';

/// Route permission check (`anyOf` or `allOf`). On failure → shell home + snackbar.
class PermissionGuard extends GetMiddleware {
  PermissionGuard({this.anyOf = const [], this.allOf = const []});

  final List<String> anyOf;
  final List<String> allOf;

  @override
  RouteSettings? redirect(String? route) {
    // Keep TokenStorage touch so refresh-token-only sessions still resolve.
    if (!Get.isRegistered<SessionService>() &&
        Get.isRegistered<TokenStorage>()) {
      Get.find<TokenStorage>();
    }
    return redirectMissingPermission(
      route: route,
      anyOf: anyOf,
      allOf: allOf,
    );
  }
}
