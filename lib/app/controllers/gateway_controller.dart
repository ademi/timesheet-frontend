import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/constants/feature_flags.dart';
import '../../core/services/token_storage.dart';
import '../routes/app_routes.dart';

enum UserRole { attendance, admin }

class GatewayController extends GetxController {
  final selectedRole = Rxn<UserRole>();

  @override
  void onInit() {
    super.onInit();
    // DOMAIN_V2: skip attendance/admin portal — actor comes from JWT after login.
    if (FeatureFlags.domainV2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppRoutes.login);
      });
      return;
    }
    if (Get.isRegistered<TokenStorage>()) {
      final stored = Get.find<TokenStorage>().role;
      for (final r in UserRole.values) {
        if (r.name == stored) {
          selectedRole.value = r;
          break;
        }
      }
    }
  }

  Future<void> selectRole(UserRole role) async {
    selectedRole.value = role;
    if (Get.isRegistered<TokenStorage>()) {
      await Get.find<TokenStorage>().persistRole(role.name);
    }
    Get.toNamed(AppRoutes.login);
  }
}
