import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../bindings/admin_panel_binding.dart';
import '../bindings/branch_gateway_binding.dart';
import '../bindings/auth_binding.dart';
import '../bindings/first_login_binding.dart';
import '../bindings/gateway_binding.dart';
import '../views/admin_panel_view.dart';
import '../views/branch_gateway_view.dart';
import '../views/first_login_view.dart';
import '../views/gateway_view.dart';
import '../views/login_view.dart';
import '../views/shell/admin_shell.dart';
import '../../features/shell/shell_routes.dart';
import 'app_routes.dart';
import 'middlewares/auth_guard.dart';

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
      name: AppRoutes.firstLogin,
      page: () => const FirstLoginView(),
      binding: FirstLoginBinding(),
      transition: Transition.fadeIn,
    ),
    // Employee attendance clock removed in S7 — redirect legacy /home to staff visits.
    GetPage(
      name: AppRoutes.home,
      middlewares: [AuthGuard()],
      page: () => const _LegacyHomeRedirect(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.adminBranchGateway,
      middlewares: [AuthGuard()],
      page: () => const BranchGatewayView(),
      binding: BranchGatewayBinding(),
      transition: Transition.rightToLeft,
    ),
    ...ShellPages.routes,
    // Legacy admin hub kept temporarily; payroll/payments product moved to StaffShell (S9).
    GetPage(
      name: AppRoutes.adminPanel,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const AdminPanelView()),
      binding: AdminPanelBinding(),
      transition: Transition.rightToLeft,
    ),
    // Legacy employee payroll periods, employee rates, and period-tied payments
    // removed in S9 — use /staff/payments and /staff/settings.
  ];
}

/// Temporary bridge for legacy `/home` (employee clock) → Staff visits.
class _LegacyHomeRedirect extends StatefulWidget {
  const _LegacyHomeRedirect();

  @override
  State<_LegacyHomeRedirect> createState() => _LegacyHomeRedirectState();
}

class _LegacyHomeRedirectState extends State<_LegacyHomeRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offAllNamed(AppRoutes.staffVisits);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
