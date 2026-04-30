import 'package:get/get.dart';

import '../controllers/gateway_controller.dart';

class GatewayBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<GatewayController>()) {
      Get.put<GatewayController>(GatewayController(), permanent: true);
    }
  }
}
