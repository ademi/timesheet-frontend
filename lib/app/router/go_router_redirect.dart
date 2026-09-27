import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/session_service.dart';
import '../../core/services/token_storage.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';

/// Public (or semi-public) locations that unauthenticated users may open.
bool isGoRouterPublicLocation(String location) {
  final path = locationPath(location);
  if (path == AppRoutes.gateway ||
      path == AppRoutes.login ||
      path == AppRoutes.firstLogin) {
    return true;
  }
  if (path == AppRoutes.contractorRegister ||
      path.startsWith('${AppRoutes.contractorRegister}/')) {
    return true;
  }
  return false;
}

/// GoRouter [redirect] mirroring [AuthGuard] + [ActorGuard] for Phase-1 routes.
String? appGoRouterRedirect(BuildContext context, GoRouterState state) {
  final loc = state.matchedLocation;

  final unauthenticated = redirectWhenUnauthenticated();
  if (unauthenticated != null) {
    if (isGoRouterPublicLocation(loc)) return null;
    return AppRoutes.gateway;
  }

  final mustChange = redirectWhenMustChangePassword(loc);
  if (mustChange != null) return mustChange.name;

  if (Get.isRegistered<TokenStorage>()) {
    final claims = Get.find<TokenStorage>().jwtClaims;
    if (Get.isRegistered<SessionService>()) {
      Get.find<SessionService>().actorType.value ??= claims?.actorType;
    }
    final actor =
        claims?.actorType ??
        (Get.isRegistered<SessionService>()
            ? Get.find<SessionService>().actorType.value
            : null);
    final wrong = redirectWrongActor(route: loc, actorType: actor);
    if (wrong != null) return wrong.name;
  }

  return null;
}
