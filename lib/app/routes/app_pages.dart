import 'package:get/get.dart';

import '../bindings/admin_panel_binding.dart';
import '../bindings/auth_binding.dart';
import '../bindings/gateway_binding.dart';
import '../bindings/home_binding.dart';
import '../views/admin_panel_view.dart';
import '../views/attendance_view.dart';
import '../views/gateway_view.dart';
import '../views/login_view.dart';
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
  ];
}
