import 'package:get/get.dart';

import '../../core/services/token_storage.dart';
import '../routes/app_routes.dart';

enum UserRole { attendance, admin }

class GatewayController extends GetxController {
  final selectedRole = Rxn<UserRole>();

  @override
  void onInit() {
    super.onInit();
    // Restore the previously chosen portal so a web refresh on a deep route does
    // not lose it (e.g. so "change branch" still knows admin vs attendance).
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
