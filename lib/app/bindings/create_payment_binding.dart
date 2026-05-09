import 'package:get/get.dart';

import '../controllers/create_payment_controller.dart';
import '../data/repositories/payment_repository.dart';
import 'payment_module_binding.dart';

class CreatePaymentBinding extends Bindings {
  @override
  void dependencies() {
    PaymentModuleBinding.ensureDependencies();
    Get.lazyPut<CreatePaymentController>(
      () => CreatePaymentController(repository: Get.find<PaymentRepository>()),
    );
  }
}
