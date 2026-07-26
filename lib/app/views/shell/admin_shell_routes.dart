import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../bindings/payment_module_binding.dart';
import '../../bindings/payroll_module_binding.dart';
import '../../routes/app_routes.dart';
import 'responsive_scaffold.dart';

/// Rail destinations and route mapping for the admin wide-screen shell.
abstract final class AdminShellRoutes {
  AdminShellRoutes._();

  static const destinations = <ResponsiveDestination>[
    ResponsiveDestination(
      icon: Icons.groups_rounded,
      label: 'Employees',
    ),
    ResponsiveDestination(
      icon: Icons.receipt_long_rounded,
      label: 'Payroll',
    ),
    ResponsiveDestination(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Payments',
    ),
  ];

  static const _employeesRoutes = {
    AppRoutes.adminPanel,
    AppRoutes.employeePicker,
  };

  static const _payrollRoutes = {
    AppRoutes.payrollMain,
    AppRoutes.payrollPeriods,
    AppRoutes.payrollSettings,
    AppRoutes.payrollPeriodDetail,
    AppRoutes.payrollPeriodResults,
    AppRoutes.payrollEmployeeRates,
    AppRoutes.payrollEmployeeRateForm,
    AppRoutes.payrollPeriodResultDetail,
    AppRoutes.payrollEmployeeBalance,
    AppRoutes.payrollSummaryReport,
  };

  static const _paymentRoutes = {
    AppRoutes.paymentMain,
    AppRoutes.paymentCreate,
    AppRoutes.paymentReport,
    AppRoutes.paymentHistory,
  };

  static bool isShellRoute(String? route) {
    if (route == null) return false;
    return _employeesRoutes.contains(route) ||
        _payrollRoutes.contains(route) ||
        _paymentRoutes.contains(route);
  }

  static int selectedIndex(String? route) {
    if (route == null) return -1;
    if (_employeesRoutes.contains(route)) return 0;
    if (_payrollRoutes.contains(route)) return 1;
    if (_paymentRoutes.contains(route)) return 2;
    return -1;
  }

  static int sectionForRoute(String? route) => selectedIndex(route);

  static String routeForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.adminPanel;
      case 1:
        return AppRoutes.payrollMain;
      case 2:
        return AppRoutes.paymentMain;
      default:
        return AppRoutes.adminPanel;
    }
  }

  static void navigateTo(int index) {
    final target = routeForIndex(index);
    final current = Get.currentRoute;

    if (current == target) return;

    if (sectionForRoute(current) == index) {
      Get.offNamed(target);
      return;
    }

    if (index == 1) PayrollModuleBinding.ensureDependencies();
    if (index == 2) PaymentModuleBinding.ensureDependencies();

    Get.offAllNamed(target);
  }
}
