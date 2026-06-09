import 'package:get/get.dart';

import '../bindings/payment_module_binding.dart';
import '../bindings/payroll_module_binding.dart';
import '../routes/app_routes.dart';

class AdminPanelController extends GetxController {
  void changeBranch() => Get.offAllNamed(AppRoutes.adminBranchGateway);

  void openEmployees() => Get.toNamed(AppRoutes.adminEmployees);

  void openAttendanceReport() => Get.toNamed(AppRoutes.adminAttendanceReport);

  void openPayroll() {
    PayrollModuleBinding.ensureDependencies();
    Get.toNamed(AppRoutes.payrollMain);
  }

  void openPayments() {
    PaymentModuleBinding.ensureDependencies();
    Get.toNamed(AppRoutes.paymentMain);
  }
}
