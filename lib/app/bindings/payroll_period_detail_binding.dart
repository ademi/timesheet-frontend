import 'package:get/get.dart';

import '../controllers/payroll_period_detail_controller.dart';
import 'payroll_module_binding.dart';

class PayrollPeriodDetailBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PayrollPeriodDetailController>(
      () => PayrollPeriodDetailController(repository: Get.find()),
    );
  }
}
