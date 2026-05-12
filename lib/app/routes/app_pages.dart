import 'package:get/get.dart';

import '../bindings/admin_panel_binding.dart';
import '../bindings/auth_binding.dart';
import '../bindings/create_payment_binding.dart';
import '../bindings/create_employee_binding.dart';
import '../bindings/employee_payment_history_binding.dart';
import '../bindings/gateway_binding.dart';
import '../bindings/home_binding.dart';
import '../bindings/payment_main_binding.dart';
import '../bindings/payments_report_binding.dart';
import '../views/admin_panel_view.dart';
import '../views/attendance_view.dart';
import '../views/create_payment_view.dart';
import '../views/create_employee_view.dart';
import '../views/employee_payment_history_view.dart';
import '../views/gateway_view.dart';
import '../views/login_view.dart';
import '../views/payment_main_view.dart';
import '../views/payments_report_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.gateway;

  static final routes = [
    GetPage(
      name: AppRoutes.gateway,
      page: () => const GatewayView(),
      binding: GatewayBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
      binding: AuthBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const AttendanceView(),
      binding: HomeBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminPanel,
      page: () => const AdminPanelView(),
      binding: AdminPanelBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.createEmployee,
      page: () => const CreateEmployeeView(),
      binding: CreateEmployeeBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentMain,
      page: () => const PaymentMainView(),
      binding: PaymentMainBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentCreate,
      page: () => const CreatePaymentView(),
      binding: CreatePaymentBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentReport,
      page: () => const PaymentsReportView(),
      binding: PaymentsReportBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentHistory,
      page: () => const EmployeePaymentHistoryView(),
      binding: EmployeePaymentHistoryBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
