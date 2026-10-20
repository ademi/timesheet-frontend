import 'package:get/get.dart';

import '../../core/getx/put_fresh.dart';
import '../controllers/reset_password_controller.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_binding.dart';

class ResetPasswordBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding().dependencies();
    putFresh(
      () => ResetPasswordController(
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
