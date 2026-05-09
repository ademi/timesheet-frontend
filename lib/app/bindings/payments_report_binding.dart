import 'package:get/get.dart';

import '../controllers/payments_report_controller.dart';
import '../data/repositories/payment_repository.dart';
import 'payment_module_binding.dart';

class PaymentsReportBinding extends Bindings {
  @override
  void dependencies() {
    PaymentModuleBinding.ensureDependencies();
    Get.lazyPut<PaymentsReportController>(
      () => PaymentsReportController(repository: Get.find<PaymentRepository>()),
    );
  }
}
