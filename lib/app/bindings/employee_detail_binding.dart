import 'package:get/get.dart';

import '../controllers/employee_detail_controller.dart';
import '../data/repositories/payroll_repository.dart';
import 'employee_module_binding.dart';
import 'payroll_module_binding.dart';

class EmployeeDetailBinding extends Bindings {
  @override
  void dependencies() {
    EmployeeModuleBinding.ensureDependencies();
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeeDetailController>(
      () => EmployeeDetailController(
        employeeRepository: Get.find(),
        payrollRepository: Get.find<PayrollRepository>(),
      ),
    );
  }
}
