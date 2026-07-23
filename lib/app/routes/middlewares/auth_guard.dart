import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/feature_flags.dart';
import '../../../core/services/token_storage.dart';
import '../../controllers/session_controller.dart';
import '../app_routes.dart';

/// Re-evaluates authentication on every resolution of a protected route.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final hasToken = Get.isRegistered<TokenStorage>() &&
        (Get.find<TokenStorage>().accessToken?.isNotEmpty ?? false);
    if (!hasToken) {
      return const RouteSettings(name: AppRoutes.gateway);
    }

    if (!FeatureFlags.domainV2) return null;

    final claims = Get.find<TokenStorage>().jwtClaims;
    if (claims?.mustChangePassword == true && route != AppRoutes.firstLogin) {
      return const RouteSettings(name: AppRoutes.firstLogin);
    }

    // Soft restore: if SessionController exists without actor, hydrate later.
    if (Get.isRegistered<SessionController>()) {
      final session = Get.find<SessionController>();
      session.actorType.value ??= claims?.actorType;
    }

    return null;
  }
}
