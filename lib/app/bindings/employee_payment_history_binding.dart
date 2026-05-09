import 'package:get/get.dart';

import '../controllers/employee_payment_history_controller.dart';
import '../data/repositories/payment_repository.dart';
import 'payment_module_binding.dart';

class EmployeePaymentHistoryBinding extends Bindings {
  @override
  void dependencies() {
    PaymentModuleBinding.ensureDependencies();
    Get.lazyPut<EmployeePaymentHistoryController>(
      () => EmployeePaymentHistoryController(
        repository: Get.find<PaymentRepository>(),
      ),
    );
  }
}
