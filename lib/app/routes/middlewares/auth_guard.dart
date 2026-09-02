import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../app_routes.dart';
import 'auth_route_utils.dart';

/// Re-evaluates authentication on every resolution of a protected route.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final unauthenticated = redirectWhenUnauthenticated();
    if (unauthenticated != null) return unauthenticated;

    final claims = Get.find<TokenStorage>().jwtClaims;
    if (claims?.mustChangePassword == true && route != AppRoutes.firstLogin) {
      return const RouteSettings(name: AppRoutes.firstLogin);
    }

    if (Get.isRegistered<SessionService>()) {
      final session = Get.find<SessionService>();
      session.actorType.value ??= claims?.actorType;
    }

    return null;
  }
}
