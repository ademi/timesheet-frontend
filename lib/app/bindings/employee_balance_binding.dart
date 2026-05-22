import 'package:get/get.dart';

import '../controllers/employee_balance_controller.dart';
import 'payroll_module_binding.dart';

class EmployeeBalanceBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeeBalanceController>(
      () => EmployeeBalanceController(repository: Get.find()),
    );
  }
}
