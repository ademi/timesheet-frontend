import 'package:get/get.dart';

import '../controllers/employee_rates_controller.dart';
import 'payroll_module_binding.dart';

class EmployeeRatesBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeeRatesController>(
      () => EmployeeRatesController(repository: Get.find()),
    );
  }
}
