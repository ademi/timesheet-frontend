import 'package:get/get.dart';

import 'auth_binding.dart';
import '../controllers/first_login_controller.dart';
import '../data/repositories/auth_repository.dart';

class FirstLoginBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding().dependencies();
    Get.lazyPut<FirstLoginController>(
      () => FirstLoginController(authRepository: Get.find<AuthRepository>()),
    );
  }
}
