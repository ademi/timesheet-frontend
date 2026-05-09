import 'package:get/get.dart';

import '../controllers/payment_main_controller.dart';
import 'payment_module_binding.dart';

class PaymentMainBinding extends Bindings {
  @override
  void dependencies() {
    PaymentModuleBinding.ensureDependencies();
    Get.lazyPut<PaymentMainController>(() => PaymentMainController());
  }
}
