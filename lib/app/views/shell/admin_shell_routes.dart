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
      icon: Icons.calendar_month_rounded,
      label: 'Report',
    ),
    ResponsiveDestination(
      icon: Icons.rule_rounded,
      label: 'Corrections',
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
    AppRoutes.adminEmployees,
    AppRoutes.employeeDetail,
    AppRoutes.createEmployee,
    AppRoutes.createEmployeeSuccess,
    AppRoutes.employeePicker,
  };

  static const _attendanceReportRoutes = {
    AppRoutes.adminAttendanceReport,
  };

  static const _correctionsRoutes = {
    AppRoutes.adminAttendanceCorrections,
    AppRoutes.adminAttendanceAdjustment,
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
        _attendanceReportRoutes.contains(route) ||
        _correctionsRoutes.contains(route) ||
        _payrollRoutes.contains(route) ||
        _paymentRoutes.contains(route);
  }

  static int selectedIndex(String? route) {
    if (route == null) return -1;
    if (_employeesRoutes.contains(route)) return 0;
    if (_attendanceReportRoutes.contains(route)) return 1;
    if (_correctionsRoutes.contains(route)) return 2;
    if (_payrollRoutes.contains(route)) return 3;
    if (_paymentRoutes.contains(route)) return 4;
    return -1;
  }

  static int sectionForRoute(String? route) => selectedIndex(route);

  static String routeForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutes.adminEmployees;
      case 1:
        return AppRoutes.adminAttendanceReport;
      case 2:
        return AppRoutes.adminAttendanceCorrections;
      case 3:
        return AppRoutes.payrollMain;
      case 4:
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

    if (index == 3) PayrollModuleBinding.ensureDependencies();
    if (index == 4) PaymentModuleBinding.ensureDependencies();

    Get.offAllNamed(target);
  }
}
