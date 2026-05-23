import 'package:get/get.dart';

import '../controllers/employee_management_controller.dart';
import 'employee_module_binding.dart';

class EmployeeManagementBinding extends Bindings {
  @override
  void dependencies() {
    EmployeeModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeeManagementController>(
      () => EmployeeManagementController(repository: Get.find()),
    );
  }
}
