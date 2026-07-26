import 'package:get/get.dart';

import '../../core/constants/feature_flags.dart';
import '../../core/services/session_service.dart';
import '../../core/services/token_storage.dart';
import '../../shared/utils/external_url.dart';
import '../routes/app_routes.dart';
import '../services/push_notification_service.dart';

class GatewayController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    _resumeIfAuthenticated();
  }

  Future<void> _resumeIfAuthenticated() async {
    if (!Get.isRegistered<TokenStorage>()) return;
    final token = Get.find<TokenStorage>().accessToken;
    if (token == null || token.isEmpty) return;

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
  }

  void goToSignIn() => Get.toNamed(AppRoutes.login);

  void goToContractorRegister() => Get.toNamed(AppRoutes.contractorRegister);

  Future<void> openProviderSignup() async {
    final ok = await openExternalUrl(AppEnv.landingUrl);
    if (!ok) {
      Get.snackbar(
        'Couldn’t open link',
        AppEnv.landingUrl,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> openBilling() async {
    final ok = await openExternalUrl(AppEnv.billingUrl);
    if (!ok) {
      Get.snackbar(
        'Couldn’t open billing',
        AppEnv.billingUrl,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
