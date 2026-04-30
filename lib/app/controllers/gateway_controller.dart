import 'package:get/get.dart';

import '../routes/app_routes.dart';

enum UserRole { attendance, admin }

class GatewayController extends GetxController {
  final selectedRole = Rxn<UserRole>();

  void selectRole(UserRole role) {
    selectedRole.value = role;
    Get.toNamed(AppRoutes.login);
  }
}
