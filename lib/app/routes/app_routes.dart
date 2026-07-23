abstract class AppRoutes {
  static const gateway = '/gateway';
  static const login = '/login';
  static const firstLogin = '/first-login';
  static const home = '/home';
  static const adminBranchGateway = '/admin/branches';
  static const adminPanel = '/admin-panel';
  static const adminEmployees = '/admin/employees';
  static const adminAttendanceReport = '/admin/attendance-report';
  static const adminAttendanceCorrections = '/admin/attendance-corrections';
  static const adminAttendanceAdjustment = '/admin/attendance-adjustment';
  static const adminShiftSchedule = '/admin/shift-schedule';
  static const employeeDetail = '/admin/employees/detail';
  static const createEmployee = '/create-employee';
  static const createEmployeeSuccess = '/create-employee/success';
  static const employeePicker = '/employees/pick';
  static const paymentMain = '/payments';
  static const paymentCreate = '/payments/create';
  static const paymentReport = '/payments/report';
  static const paymentHistory = '/payments/history';
  static const payrollMain = '/payroll';
  static const payrollPeriods = '/payroll/periods';
  static const payrollSettings = '/payroll/settings';
  static const payrollPeriodDetail = '/payroll/periods/detail';
  static const payrollPeriodResults = '/payroll/periods/results';
  static const payrollEmployeeRates = '/payroll/rates';
  static const payrollEmployeeRateForm = '/payroll/rates/form';
  static const payrollPeriodResultDetail = '/payroll/periods/results/detail';
  static const payrollEmployeeBalance = '/payroll/balance';
  static const payrollSummaryReport = '/payroll/summary';

  /// Employee self-service portal (F-02).
  static const employeePortal = '/employee';
  static const employeeMyHours = '/employee/my-hours';
  static const employeeMySchedule = '/employee/my-schedule';

  /// Thin admin ops screens (F-03 / F-06).
  static const adminAudit = '/admin/audit';
  static const adminNotifications = '/admin/notifications';
  static const adminGeofence = '/admin/geofence';
  static const adminBilling = '/admin/billing';
}
