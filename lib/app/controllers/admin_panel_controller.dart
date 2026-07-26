import 'package:get/get.dart';

import '../routes/app_routes.dart';

class AdminPanelController extends GetxController {
  void changeBranch() => Get.offAllNamed(AppRoutes.adminBranchGateway);

  void openEmployees() {
    Get.toNamed(AppRoutes.staffWorkforce);
  }

  void openVisits() => Get.toNamed(AppRoutes.staffVisits);

  void openPayments() => Get.toNamed(AppRoutes.staffPayments);

  void openSettings() => Get.toNamed(AppRoutes.staffSettings);
}
