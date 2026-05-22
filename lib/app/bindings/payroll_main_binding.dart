import 'package:get/get.dart';

import '../controllers/payroll_main_controller.dart';
import 'payroll_module_binding.dart';

class PayrollMainBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PayrollMainController>(
      () => PayrollMainController(repository: Get.find()),
    );
  }
}
