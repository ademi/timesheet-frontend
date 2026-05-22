import 'package:get/get.dart';

import '../controllers/payroll_period_results_controller.dart';
import 'payroll_module_binding.dart';

class PayrollPeriodResultsBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PayrollPeriodResultsController>(
      () => PayrollPeriodResultsController(repository: Get.find()),
    );
  }
}
