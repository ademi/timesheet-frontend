import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/constants/feature_flags.dart';
import '../../core/services/session_service.dart';
import '../../core/services/token_refresh_service.dart';
import '../../core/services/token_storage.dart';
import '../../shared/utils/external_url.dart';
import '../../shared/widgets/app_toast.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import '../services/push_notification_service.dart';

class GatewayController extends GetxController {
  GatewayController({this.entryLocationOverride});

  /// Test seam: force the "current entry" location used by session resume.
  @visibleForTesting
  final String? entryLocationOverride;

  final isRestoringSession = false.obs;

  @override
  void onInit() {
    super.onInit();
    _resumeIfAuthenticated();
  }

  Future<void> _resumeIfAuthenticated() async {
    if (!Get.isRegistered<TokenStorage>()) return;

    isRestoringSession.value = true;
    try {
      final tokenStorage = Get.find<TokenStorage>();
      if (Get.isRegistered<TokenRefreshService>()) {
        final outcome = await Get.find<TokenRefreshService>().refreshIfNeeded();
        if (outcome == TokenRefreshOutcome.invalidRefreshToken) return;
      }

      if (!tokenStorage.hasValidAccessToken) return;

      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        await session.hydrateFromMeContext();
        if (Get.isRegistered<PushNotificationService>()) {
          await Get.find<PushNotificationService>()
              .registerCurrentDeviceToken();
        }
        final route = session.resolvePostLoginRoute();
        if (route == AppRoutes.login || route == AppRoutes.gateway) return;

        // F4.1: never yank the user off a valid deep link after session hydrate.
        // Only resume → home when entry was gateway / empty.
        if (!shouldNavigateAfterSessionResume(
          entryLocation: entryLocationOverride,
        )) {
          return;
        }
        AppNavigator.offAll(route);
      }
    } finally {
      isRestoringSession.value = false;
    }
  }

  void goToSignIn() => AppNavigator.push(AppRoutes.login);

  void goToContractorRegister() =>
      AppNavigator.push(AppRoutes.contractorRegister);

  Future<void> openProviderSignup() async {
    final ok = await openExternalUrl(AppEnv.landingUrl);
    if (!ok) {
      AppToast.error('Couldn’t open link', AppEnv.landingUrl);
    }
  }

  Future<void> openBilling() async {
    final ok = await openExternalUrl(AppEnv.billingUrl);
    if (!ok) {
      AppToast.error('Couldn’t open billing', AppEnv.billingUrl);
    }
  }
}
