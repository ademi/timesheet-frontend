/// Permission keys used by admin route guards and hub card filtering (S-05).
class AppPermissions {
  AppPermissions._();

  static const employeesRead = 'employees.read';
  static const employeesManage = 'employees.manage';
  static const attendanceView = 'attendance.view';
  static const attendanceViewOwn = 'attendance.view_own';
  static const attendanceOverride = 'attendance.override';
  static const attendancePunch = 'attendance.punch';
  static const schedulingRead = 'scheduling.read';
  static const schedulingViewOwn = 'scheduling.view_own';
  static const schedulingManage = 'scheduling.manage';
  static const payrollView = 'payroll.view';
  static const payrollManage = 'payroll.manage';
  static const paymentsView = 'payments.view';
  static const paymentsManage = 'payments.manage';
  static const auditView = 'audit.view';
  static const notificationsReceive = 'notifications.receive';
  static const notificationsManage = 'notifications.manage';
  static const geofenceRead = 'geofence.read';
  static const geofenceManage = 'geofence.manage';
  static const subscriptionView = 'subscription.view';
  static const subscriptionManage = 'subscription.manage';

  static const adminPortalAny = [
    employeesRead,
    attendanceView,
    attendanceOverride,
    schedulingRead,
    payrollView,
    paymentsView,
    auditView,
    notificationsReceive,
    geofenceRead,
    subscriptionView,
  ];

  static const employeePortalAny = [
    attendanceViewOwn,
    schedulingViewOwn,
  ];
}
