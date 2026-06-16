import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/token_storage.dart';
import '../app_routes.dart';

/// Re-evaluates authentication on every resolution of a protected route.
///
/// On web a browser refresh rebuilds GetX's navigation from the URL alone. Without
/// a guard, deep protected routes could resolve before auth is considered and the
/// browser-history/GetX-stack mismatch could bounce the user toward login/logout.
/// Running this on each resolution means a refresh deterministically lands on a
/// valid screen: authenticated users stay, unauthenticated users go to [gateway].
///
/// Reads the live source of truth ([TokenStorage], backed by secure storage) via
/// GetX dependency injection. Identical behaviour on mobile, where the token cache
/// is already warm, so authenticated users are never interrupted.
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final hasToken = Get.isRegistered<TokenStorage>() &&
        (Get.find<TokenStorage>().accessToken?.isNotEmpty ?? false);
    if (hasToken) return null;
    return const RouteSettings(name: AppRoutes.gateway);
  }
}
