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
import '../views/shell/v2_shells.dart';
import '../views/v2/domain_stub_view.dart';
import '../views/v2/wrong_actor_view.dart';
import 'app_routes.dart';
import 'middlewares/actor_guard.dart';
import 'middlewares/auth_guard.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.gateway;

  static List<GetPage> get _v2Routes => [
        GetPage(
          name: AppRoutes.wrongActor,
          page: () => const WrongActorView(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminHub,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => adminV2ShellPage(const DomainStubView(title: 'Admin Hub')),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminTeam,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () =>
              adminV2ShellPage(const DomainStubView(title: 'Team')),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminEngagements,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => adminV2ShellPage(
            const DomainStubView(title: 'Contractors / Engagements'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminClients,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () =>
              adminV2ShellPage(const DomainStubView(title: 'Clients')),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminJobs,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => adminV2ShellPage(
            const DomainStubView(title: 'Jobs / Visits'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminPayments,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () =>
              adminV2ShellPage(const DomainStubView(title: 'Payments')),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminForms,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () =>
              adminV2ShellPage(const DomainStubView(title: 'Forms')),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.adminSettings,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => adminV2ShellPage(
            const DomainStubView(title: 'Branches / Settings'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorVisits,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Visits'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorVisitDetail,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Visit detail'),
          ),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.contractorTimetable,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Timetable'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorDocuments,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Documents'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorPayments,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(
              title: 'Payments',
              subtitle: 'Filter own visits by payment_status (Phase 3).',
            ),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorSwitchTenant,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Switch tenant'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorProfile,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Profile'),
          ),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorEngagementAccept,
          middlewares: [AuthGuard(), ActorGuard()],
          page: () => contractorShellPage(
            const DomainStubView(title: 'Accept engagement'),
          ),
          transition: Transition.fadeIn,
        ),
      ];

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
      middlewares: [AuthGuard()],
      page: () => const AttendanceView(),
      binding: HomeBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminBranchGateway,
      middlewares: [AuthGuard()],
      page: () => const BranchGatewayView(),
      binding: BranchGatewayBinding(),
      transition: Transition.rightToLeft,
    ),
    ..._v2Routes,
    // Legacy admin routes continue below (Phase 3 removes obsolete ones).
    GetPage(
      name: AppRoutes.adminPanel,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const AdminPanelView()),
      binding: AdminPanelBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminEmployees,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeeManagementView()),
      binding: EmployeeManagementBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAttendanceReport,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const AttendanceReportView()),
      binding: AttendanceReportBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAttendanceCorrections,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const AttendanceCorrectionsView()),
      binding: AttendanceCorrectionsBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminShiftSchedule,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const ShiftScheduleView()),
      binding: ShiftScheduleBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminAttendanceAdjustment,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const AttendanceAdjustmentView()),
      binding: AttendanceAdjustmentBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.employeeDetail,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeeDetailView()),
      binding: EmployeeDetailBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.createEmployee,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const CreateEmployeeView()),
      binding: CreateEmployeeBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.createEmployeeSuccess,
      middlewares: [AuthGuard()],
      page: () => adminShellPage(const EmployeeCreatedView()),
      transition: Transition.rightToLeft,
    ),
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
