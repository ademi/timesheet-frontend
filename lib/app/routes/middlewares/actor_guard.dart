import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import 'auth_route_utils.dart';

/// Ensures the signed-in actor matches the shell.
class ActorGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final unauthenticated = redirectWhenUnauthenticated();
    if (unauthenticated != null) return unauthenticated;

    final mustChange = redirectWhenMustChangePassword(route);
    if (mustChange != null) return mustChange;

    final claims = Get.find<TokenStorage>().jwtClaims;
    final actor =
        claims?.actorType ??
        (Get.isRegistered<SessionService>()
            ? Get.find<SessionService>().actorType.value
            : null);

    return redirectWrongActor(route: route, actorType: actor);
  }
}
