import 'package:get/get.dart';

import '../bindings/admin_panel_binding.dart';
import '../bindings/branch_gateway_binding.dart';
import '../bindings/attendance_adjustment_binding.dart';
import '../bindings/attendance_corrections_binding.dart';
import '../bindings/attendance_report_binding.dart';
import '../bindings/employee_detail_binding.dart';
import '../bindings/employee_management_binding.dart';
import '../bindings/auth_binding.dart';
import '../bindings/create_payment_binding.dart';
import '../bindings/create_employee_binding.dart';
import '../bindings/employee_balance_binding.dart';
import '../bindings/employee_payment_history_binding.dart';
import '../bindings/employee_picker_binding.dart';
import '../bindings/employee_rate_form_binding.dart';
import '../bindings/employee_rates_binding.dart';
import '../bindings/first_login_binding.dart';
import '../bindings/gateway_binding.dart';
import '../bindings/home_binding.dart';
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
import '../views/attendance_adjustment_view.dart';
import '../views/attendance_corrections_view.dart';
import '../views/attendance_report_view.dart';
import '../views/attendance_view.dart';
import '../views/employee_detail_view.dart';
import '../views/employee_management_view.dart';
import '../views/create_payment_view.dart';
import '../views/create_employee_view.dart';
import '../views/employee_balance_view.dart';
import '../views/employee_payment_history_view.dart';
import '../views/employee_created_view.dart';
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
import '../bindings/shift_schedule_binding.dart';
import '../views/shift_schedule_view.dart';
import '../views/payroll_summary_report_view.dart';
import '../views/shell/admin_shell.dart';
import '../views/employee_portal_view.dart';
import '../views/employee_my_hours_view.dart';
import '../views/admin_ops_views.dart';
import '../controllers/employee_portal_controller.dart';
import '../constants/app_permissions.dart';
import 'app_routes.dart';
import 'middlewares/auth_guard.dart';
import 'middlewares/permission_guard.dart';

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
    GetPage(
      name: AppRoutes.home,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.attendancePunch]),
      ],
      page: () => const AttendanceView(),
      binding: HomeBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminBranchGateway,
      middlewares: [
        AuthGuard(),
        PermissionGuard(
          requiredAny: [
            ...AppPermissions.adminPortalAny,
            ...AppPermissions.employeePortalAny,
            AppPermissions.attendancePunch,
          ],
        ),
      ],
      page: () => const BranchGatewayView(),
      binding: BranchGatewayBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminPanel,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: AppPermissions.adminPortalAny),
      ],
      page: () => adminShellPage(const AdminPanelView()),
      binding: AdminPanelBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminEmployees,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.employeesRead]),
      ],
      page: () => adminShellPage(const EmployeeManagementView()),
      binding: EmployeeManagementBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAttendanceReport,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.attendanceView]),
      ],
      page: () => adminShellPage(const AttendanceReportView()),
      binding: AttendanceReportBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAttendanceCorrections,
      middlewares: [
        AuthGuard(),
        PermissionGuard(
          requiredAny: [
            AppPermissions.attendanceView,
            AppPermissions.attendanceOverride,
          ],
        ),
      ],
      page: () => adminShellPage(const AttendanceCorrectionsView()),
      binding: AttendanceCorrectionsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminShiftSchedule,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.schedulingRead]),
      ],
      page: () => adminShellPage(const ShiftScheduleView()),
      binding: ShiftScheduleBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAttendanceAdjustment,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.attendanceOverride]),
      ],
      page: () => adminShellPage(const AttendanceAdjustmentView()),
      binding: AttendanceAdjustmentBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.employeeDetail,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.employeesRead]),
      ],
      page: () => adminShellPage(const EmployeeDetailView()),
      binding: EmployeeDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.createEmployee,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.employeesManage]),
      ],
      page: () => adminShellPage(const CreateEmployeeView()),
      binding: CreateEmployeeBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.createEmployeeSuccess,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.employeesManage]),
      ],
      page: () => adminShellPage(const EmployeeCreatedView()),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.employeePicker,
      middlewares: [
        AuthGuard(),
        PermissionGuard(
          requiredAny: [
            AppPermissions.employeesRead,
            AppPermissions.paymentsView,
            AppPermissions.payrollView,
          ],
        ),
      ],
      page: () => adminShellPage(const EmployeePickerView()),
      binding: EmployeePickerBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentMain,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.paymentsView]),
      ],
      page: () => adminShellPage(const PaymentMainView()),
      binding: PaymentMainBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentCreate,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.paymentsManage]),
      ],
      page: () => adminShellPage(const CreatePaymentView()),
      binding: CreatePaymentBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentReport,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.paymentsView]),
      ],
      page: () => adminShellPage(const PaymentsReportView()),
      binding: PaymentsReportBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.paymentHistory,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.paymentsView]),
      ],
      page: () => adminShellPage(const EmployeePaymentHistoryView()),
      binding: EmployeePaymentHistoryBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollMain,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const PayrollMainView()),
      binding: PayrollMainBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriods,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const PayrollPeriodsView()),
      binding: PayrollPeriodsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollSettings,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollManage]),
      ],
      page: () => adminShellPage(const PayrollSettingsView()),
      binding: PayrollSettingsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriodDetail,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const PayrollPeriodDetailView()),
      binding: PayrollPeriodDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriodResults,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const PayrollPeriodResultsView()),
      binding: PayrollPeriodResultsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollEmployeeRates,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const EmployeeRatesView()),
      binding: EmployeeRatesBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollEmployeeRateForm,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollManage]),
      ],
      page: () => adminShellPage(const EmployeeRateFormView()),
      binding: EmployeeRateFormBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollPeriodResultDetail,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const PayrollResultDetailView()),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollEmployeeBalance,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const EmployeeBalanceView()),
      binding: EmployeeBalanceBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.payrollSummaryReport,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.payrollView]),
      ],
      page: () => adminShellPage(const PayrollSummaryReportView()),
      binding: PayrollSummaryReportBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.employeePortal,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: AppPermissions.employeePortalAny),
      ],
      page: () => const EmployeePortalView(),
      binding: EmployeePortalBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.employeeMyHours,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.attendanceViewOwn]),
      ],
      page: () => const EmployeeMyHoursView(),
      binding: EmployeeMyHoursBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.employeeMySchedule,
      middlewares: [
        AuthGuard(),
        PermissionGuard(
          requiredAny: [
            AppPermissions.schedulingViewOwn,
            AppPermissions.schedulingRead,
          ],
        ),
      ],
      page: () => const EmployeeMyScheduleView(),
      binding: EmployeeMyScheduleBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAudit,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.auditView]),
      ],
      page: () => adminShellPage(const AdminOpsListView()),
      binding: AdminAuditBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminNotifications,
      middlewares: [
        AuthGuard(),
        PermissionGuard(
          requiredAny: [
            AppPermissions.notificationsReceive,
            AppPermissions.notificationsManage,
          ],
        ),
      ],
      page: () => adminShellPage(const AdminOpsListView()),
      binding: AdminNotificationsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminGeofence,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.geofenceRead]),
      ],
      page: () => adminShellPage(const AdminOpsListView()),
      binding: AdminGeofenceBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminBilling,
      middlewares: [
        AuthGuard(),
        PermissionGuard(requiredAny: [AppPermissions.subscriptionView]),
      ],
      page: () => adminShellPage(const AdminBillingView()),
      binding: AdminBillingBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
