import 'package:get/get.dart';

import '../controllers/payroll_periods_controller.dart';
import 'payroll_module_binding.dart';

class PayrollPeriodsBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PayrollPeriodsController>(
      () => PayrollPeriodsController(
        repository: Get.find(),
        settingsStorage: Get.find(),
      ),
    );
  }
}
