import 'package:get/get.dart';

import '../bindings/auth_binding.dart';
import '../bindings/home_binding.dart';
import '../views/attendance_view.dart';
import '../views/login_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.login;

  static final routes = [
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
  ];
}
