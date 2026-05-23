import 'package:get/get.dart';

import '../controllers/create_payment_controller.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/payroll_repository.dart';
import 'payment_module_binding.dart';
import 'payroll_module_binding.dart';

class CreatePaymentBinding extends Bindings {
  @override
  void dependencies() {
    PaymentModuleBinding.ensureDependencies();
    PayrollModuleBinding.ensureDependencies();
    Get.lazyPut<CreatePaymentController>(
      () => CreatePaymentController(
        paymentRepository: Get.find<PaymentRepository>(),
        payrollRepository: Get.find<PayrollRepository>(),
      ),
    );
  }
}
