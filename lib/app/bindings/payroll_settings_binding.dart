import 'package:get/get.dart';

import '../controllers/payroll_settings_controller.dart';
import 'payroll_module_binding.dart';

class PayrollSettingsBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PayrollSettingsController>(
      () => PayrollSettingsController(storage: Get.find()),
    );
  }
}
