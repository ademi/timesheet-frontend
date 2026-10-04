import 'package:get/get.dart';

import '../../core/getx/put_fresh.dart';
import '../controllers/first_login_controller.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_binding.dart';

class FirstLoginBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding().dependencies();
    // Clear password fields if the user leaves and returns to first-login.
    putFresh(
      () => FirstLoginController(authRepository: Get.find<AuthRepository>()),
    );
  }
}
