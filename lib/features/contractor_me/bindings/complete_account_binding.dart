import 'package:get/get.dart';

import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../controllers/complete_account_controller.dart';

class CompleteAccountBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    Get.lazyPut(CompleteAccountController.new);
  }
}
