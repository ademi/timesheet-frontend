import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../bindings/admin_panel_binding.dart';
import '../bindings/branch_gateway_binding.dart';
import '../bindings/auth_binding.dart';
import '../bindings/create_payment_binding.dart';
import '../bindings/employee_balance_binding.dart';
import '../bindings/employee_payment_history_binding.dart';
import '../bindings/employee_picker_binding.dart';
import '../bindings/employee_rate_form_binding.dart';
import '../bindings/employee_rates_binding.dart';
import '../bindings/first_login_binding.dart';
import '../bindings/gateway_binding.dart';
import '../bindings/payment_main_binding.dart';
import '../bindings/payments_report_binding.dart';
import '../bindings/payroll_main_binding.dart';
import '../bindings/payroll_period_detail_binding.dart';
import '../bindings/payroll_period_results_binding.dart';
import '../bindings/payroll_periods_binding.dart';
import '../bindings/payroll_settings_binding.dart';
import '../bindings/payroll_summary_report_binding.dart';
import '../views/admin_panel_view.dart';
import '../views/branch_gateway_view.dart';
import '../views/create_payment_view.dart';
import '../views/employee_balance_view.dart';
import '../views/employee_payment_history_view.dart';
import '../views/employee_picker_view.dart';
import '../views/employee_rate_form_view.dart';
import '../views/employee_rates_view.dart';
import '../views/payroll_result_detail_view.dart';
import '../views/first_login_view.dart';
import '../views/gateway_view.dart';
import '../views/login_view.dart';
import '../views/payment_main_view.dart';
import '../views/payments_report_view.dart';
import '../views/payroll_main_view.dart';
import '../views/payroll_period_detail_view.dart';
import '../views/payroll_period_results_view.dart';
import '../views/payroll_periods_view.dart';
import '../views/payroll_settings_view.dart';
import '../views/payroll_summary_report_view.dart';
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
    // Legacy admin routes continue below (deleted as slices land).
    GetPage(
      name: AppRoutes.adminPanel,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const AdminPanelView()),
      binding: AdminPanelBinding(),
      transition: Transition.rightToLeft,
    ),
    // Attendance report / corrections / adjustment removed in S7 (replaced by Visits).
    // Employee management CRUD removed in S4 (replaced by Workforce).
    // Employee picker kept temporarily for legacy payment/payroll flows.
    GetPage(
      name: AppRoutes.employeePicker,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeePickerView()),
      binding: EmployeePickerBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentMain,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PaymentMainView()),
      binding: PaymentMainBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentCreate,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const CreatePaymentView()),
      binding: CreatePaymentBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentReport,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PaymentsReportView()),
      binding: PaymentsReportBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentHistory,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeePaymentHistoryView()),
      binding: EmployeePaymentHistoryBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollMain,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollMainView()),
      binding: PayrollMainBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriods,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollPeriodsView()),
      binding: PayrollPeriodsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollSettings,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollSettingsView()),
      binding: PayrollSettingsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriodDetail,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollPeriodDetailView()),
      binding: PayrollPeriodDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriodResults,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollPeriodResultsView()),
      binding: PayrollPeriodResultsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollEmployeeRates,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeeRatesView()),
      binding: EmployeeRatesBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollEmployeeRateForm,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeeRateFormView()),
      binding: EmployeeRateFormBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriodResultDetail,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollResultDetailView()),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollEmployeeBalance,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeeBalanceView()),
      binding: EmployeeBalanceBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollSummaryReport,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const PayrollSummaryReportView()),
      binding: PayrollSummaryReportBinding(),
      transition: Transition.rightToLeft,
    ),
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
