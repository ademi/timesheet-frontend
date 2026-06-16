import 'package:get/get.dart';

import '../controllers/gateway_controller.dart';
import 'auth_binding.dart';

/// Registers session-scoped dependencies that any screen may need, regardless of
/// the entry route.
///
/// On web a refresh rebuilds the app from the current URL alone, so only that
/// route's binding (plus this initial binding) runs. Controllers that are
/// otherwise registered by a *different* route's binding — [GatewayController]
/// (gateway route) and the auth graph incl. AuthController (login route) — would
/// then be missing, causing "X not found" errors on deep-route refreshes. Wiring
/// them here makes them available on every entry point. All registrations are
/// idempotent, so this is safe to run alongside the per-route bindings.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Core auth/API graph (TokenStorage, ApiClient, repositories, AuthController…).
    AuthBinding().dependencies();

    if (!Get.isRegistered<GatewayController>()) {
      Get.put<GatewayController>(GatewayController(), permanent: true);
    }
  }
}
