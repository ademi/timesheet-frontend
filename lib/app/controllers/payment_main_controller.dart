import 'package:get/get.dart';

import '../routes/app_routes.dart';

class PaymentMainController extends GetxController {
  void openCreatePayment() => Get.toNamed(AppRoutes.paymentCreate);

  void openPaymentsReport() => Get.toNamed(AppRoutes.paymentReport);

  void openEmployeeHistory() => Get.toNamed(AppRoutes.paymentHistory);
}
