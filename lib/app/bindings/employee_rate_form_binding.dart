import 'package:get/get.dart';

import '../controllers/employee_rate_form_controller.dart';
import 'payroll_module_binding.dart';

class EmployeeRateFormBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeeRateFormController>(
      () => EmployeeRateFormController(repository: Get.find()),
    );
  }
}
