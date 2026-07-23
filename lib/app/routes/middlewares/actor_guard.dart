import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/constants/feature_flags.dart';
import '../../../core/services/token_storage.dart';
import '../../controllers/session_controller.dart';
import '../../views/shell/v2_shells.dart';
import '../app_routes.dart';

/// Ensures the signed-in actor matches the shell for DOMAIN_V2 routes.
class ActorGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!FeatureFlags.domainV2) return null;

    final hasToken = Get.isRegistered<TokenStorage>() &&
        (Get.find<TokenStorage>().accessToken?.isNotEmpty ?? false);
    if (!hasToken) {
      return const RouteSettings(name: AppRoutes.gateway);
    }

    final claims = Get.find<TokenStorage>().jwtClaims;
    final actor = claims?.actorType ??
        (Get.isRegistered<SessionController>()
            ? Get.find<SessionController>().actorType.value
            : null);

    if (claims?.mustChangePassword == true) {
      return const RouteSettings(name: AppRoutes.firstLogin);
    }

    if (isAdminV2Route(route)) {
      if (actor != null && actor != 'tenant_member') {
        return const RouteSettings(name: AppRoutes.wrongActor);
      }
    }

    if (isContractorV2Route(route)) {
      if (actor != null && actor != 'contractor') {
        return const RouteSettings(name: AppRoutes.wrongActor);
      }
    }

    return null;
  }
}
