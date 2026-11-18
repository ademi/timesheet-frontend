import 'package:get/get.dart';

import '../../core/getx/put_fresh.dart';
import '../controllers/landing_auth_handoff_controller.dart';
import 'auth_binding.dart';

class LandingAuthHandoffBinding extends Bindings {
  @override
  void dependencies() {
    AuthBinding().dependencies();
    putFresh(() => LandingAuthHandoffController());
  }
}
