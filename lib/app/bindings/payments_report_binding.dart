import 'package:get/get.dart';

import '../controllers/payments_report_controller.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/payroll_repository.dart';
import 'payment_module_binding.dart';
import 'payroll_module_binding.dart';

class PaymentsReportBinding extends Bindings {
  @override
  void dependencies() {
    PaymentModuleBinding.ensureDependencies();
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<PaymentsReportController>(
      () => PaymentsReportController(
        paymentRepository: Get.find<PaymentRepository>(),
        payrollRepository: Get.find<PayrollRepository>(),
      ),
    );
  }
}
