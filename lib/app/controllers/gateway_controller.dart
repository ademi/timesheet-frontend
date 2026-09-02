import 'package:get/get.dart';

import '../../core/constants/feature_flags.dart';
import '../../core/services/session_service.dart';
import '../../core/services/token_refresh_service.dart';
import '../../core/services/token_storage.dart';
import '../../shared/utils/external_url.dart';
import '../../shared/widgets/app_toast.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';

class GatewayController extends GetxController {
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
        final outcome =
            await Get.find<TokenRefreshService>().refreshIfNeeded();
        if (outcome == TokenRefreshOutcome.invalidRefreshToken) return;
      }

      if (!tokenStorage.hasValidAccessToken) return;

      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        await session.hydrateFromMeContext();
        if (Get.isRegistered<PushNotificationService>()) {
          await Get.find<PushNotificationService>().registerCurrentDeviceToken();
        }
        final route = session.resolvePostLoginRoute();
        if (route != AppRoutes.login && route != AppRoutes.gateway) {
          Get.offAllNamed(route);
        }
      }
    } finally {
      isRestoringSession.value = false;
    }
  }

  void goToSignIn() => Get.toNamed(AppRoutes.login);

  void goToContractorRegister() => Get.toNamed(AppRoutes.contractorRegister);

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
