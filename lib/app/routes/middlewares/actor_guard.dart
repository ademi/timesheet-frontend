import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../../features/shell/contractor_shell.dart';
import '../../../features/shell/staff_shell.dart';
import '../app_routes.dart';

/// Ensures the signed-in actor matches the shell.
class ActorGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final hasToken = Get.isRegistered<TokenStorage>() &&
        (Get.find<TokenStorage>().accessToken?.isNotEmpty ?? false);
    if (!hasToken) {
      return const RouteSettings(name: AppRoutes.gateway);
    }

    final claims = Get.find<TokenStorage>().jwtClaims;
    final actor = claims?.actorType ??
        (Get.isRegistered<SessionService>()
            ? Get.find<SessionService>().actorType.value
            : null);

    if (claims?.mustChangePassword == true) {
      return const RouteSettings(name: AppRoutes.firstLogin);
    }

    if (isStaffRoute(route)) {
      if (actor != null && actor != 'tenant_member') {
        return const RouteSettings(name: AppRoutes.wrongActor);
      }
    }

    if (isContractorShellRoute(route) ||
        (route != null &&
            (route.startsWith(AppRoutes.contractorOnboarding) ||
                route == AppRoutes.contractorCompleteAccount))) {
      if (actor != null && actor != 'contractor') {
        return const RouteSettings(name: AppRoutes.wrongActor);
      }
    }

    return null;
  }
}
