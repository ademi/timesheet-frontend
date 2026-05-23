import 'package:get/get.dart';

import '../controllers/employee_picker_controller.dart';
import 'payroll_module_binding.dart';

class EmployeePickerBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeePickerController>(
      () => EmployeePickerController(repository: Get.find()),
    );
  }
}
