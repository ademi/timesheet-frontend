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

  // --- DOMAIN_V2 dual shells ---
  static const wrongActor = '/wrong-actor';
  static const adminHub = '/v2/admin/hub';
  static const adminTeam = '/v2/admin/team';
  static const adminEngagements = '/v2/admin/engagements';
  static const adminClients = '/v2/admin/clients';
  static const adminJobs = '/v2/admin/jobs';
  static const adminPayments = '/v2/admin/payments';
  static const adminForms = '/v2/admin/forms';
  static const adminSettings = '/v2/admin/settings';

  static const contractorVisits = '/v2/contractor/visits';
  static const contractorVisitDetail = '/v2/contractor/visits/detail';
  static const contractorTimetable = '/v2/contractor/timetable';
  static const contractorDocuments = '/v2/contractor/documents';
  static const contractorPayments = '/v2/contractor/payments';
  static const contractorSwitchTenant = '/v2/contractor/switch-tenant';
  static const contractorProfile = '/v2/contractor/profile';
  static const contractorEngagementAccept = '/v2/contractor/engagements/accept';
}

/// Admin shell route names (DOMAIN_V2).
abstract final class AdminRoutes {
  AdminRoutes._();

  static const hub = AppRoutes.adminHub;
  static const team = AppRoutes.adminTeam;
  static const engagements = AppRoutes.adminEngagements;
  static const clients = AppRoutes.adminClients;
  static const jobs = AppRoutes.adminJobs;
  static const payments = AppRoutes.adminPayments;
  static const forms = AppRoutes.adminForms;
  static const settings = AppRoutes.adminSettings;

  static const List<String> all = [
    hub,
    team,
    engagements,
    clients,
    jobs,
    payments,
    forms,
    settings,
  ];
}

/// Contractor shell route names (DOMAIN_V2).
abstract final class ContractorRoutes {
  ContractorRoutes._();

  static const visits = AppRoutes.contractorVisits;
  static const visitDetail = AppRoutes.contractorVisitDetail;
  static const timetable = AppRoutes.contractorTimetable;
  static const documents = AppRoutes.contractorDocuments;
  static const payments = AppRoutes.contractorPayments;
  static const switchTenant = AppRoutes.contractorSwitchTenant;
  static const profile = AppRoutes.contractorProfile;
  static const engagementAccept = AppRoutes.contractorEngagementAccept;

  static const List<String> all = [
    visits,
    visitDetail,
    timetable,
    documents,
    payments,
    switchTenant,
    profile,
    engagementAccept,
  ];
}
