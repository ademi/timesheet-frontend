import 'package:get/get.dart';

import '../controllers/payroll_summary_report_controller.dart';
import 'payroll_module_binding.dart';

class PayrollSummaryReportBinding extends Bindings {
  @override
  void dependencies() {
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PayrollSummaryReportController>(
      () => PayrollSummaryReportController(repository: Get.find()),
    );
  }
}
