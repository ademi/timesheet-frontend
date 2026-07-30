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
  @Deprecated('Removed in S7; use staffVisits')
  static const adminAttendanceAdjustment = '/admin/attendance-adjustment';

  /// Removed in S6 — use Staff Jobs (`staffJobs`) instead.
  @Deprecated('Removed in S6; use staffJobs')
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

  // --- Dual shells (contractor domain) ---
  static const wrongActor = '/wrong-actor';

  // StaffShell
  static const staffHome = '/staff/home';
  static const staffWorkforce = '/staff/workforce';
  static const staffWorkforceInvite = '/staff/workforce/invite';
  static const staffWorkforceDetail = '/staff/workforce/detail';
  static const staffClients = '/staff/clients';
  static const staffClientForm = '/staff/clients/form';
  static const staffClientDetail = '/staff/clients/detail';
  static const staffClientSiteForm = '/staff/clients/site-form';
  static const staffClientContactForm = '/staff/clients/contact-form';
  static const staffJobs = '/staff/jobs';
  static const staffJobForm = '/staff/jobs/form';
  static const staffJobDetail = '/staff/jobs/detail';
  static const staffRecurrenceRuleForm = '/staff/jobs/recurrence-rule-form';
  static const staffFormTemplates = '/staff/jobs/form-templates';
  static const staffVisits = '/staff/visits';
  static const staffVisitDetail = '/staff/visits/detail';
  static const staffPayments = '/staff/payments';
  static const staffCompliance = '/staff/compliance';
  static const staffSettings = '/staff/settings';
  static const staffCredentialReview = '/staff/credentials-review';

  // ContractorShell + public / onboarding
  static const contractorRegister = '/contractor/register';
  static const contractorOnboarding = '/contractor/onboarding';
  static const contractorOnboardingLegal = '/contractor/onboarding/legal';
  static const contractorOnboardingNotices = '/contractor/onboarding/notices';
  static const contractorOnboardingConsents = '/contractor/onboarding/consents';
  static const contractorOnboardingEngagement =
      '/contractor/onboarding/engagement';
  static const contractorOnboardingCredentials =
      '/contractor/onboarding/credentials';
  static const contractorHome = '/contractor/home';
  static const contractorVisits = '/contractor/visits';
  static const contractorVisitDetail = '/contractor/visits/detail';
  static const contractorSchedule = '/contractor/schedule';
  static const contractorCredentials = '/contractor/credentials';
  static const contractorCredentialCreate = '/contractor/credentials/create';
  static const contractorCredentialDetail = '/contractor/credentials/detail';
  static const contractorProfile = '/contractor/profile';
  static const contractorPayments = '/contractor/payments';

  /// Public client invite acknowledge (design §4.1 / §6.6).
  static const publicClientInvite = '/invites/client/:token';

  /// Alias for backend email links (`public_app_base_url/invite/{token}`).
  static const publicClientInviteLegacy = '/invite/:token';

  // Deprecated aliases (removed /v2 stubs) — keep names for any leftover refs.
  @Deprecated('Use staffHome')
  static const adminHub = staffHome;
  @Deprecated('Use staffWorkforce')
  static const adminTeam = staffWorkforce;
  @Deprecated('Use staffWorkforce')
  static const adminEngagements = staffWorkforce;
  @Deprecated('Use staffClients')
  static const adminClients = staffClients;
  @Deprecated('Use staffJobs')
  static const adminJobs = staffJobs;
  @Deprecated('Use staffPayments')
  static const adminPayments = staffPayments;
  @Deprecated('Use staffSettings')
  static const adminForms = staffSettings;
  @Deprecated('Use staffSettings')
  static const adminSettings = staffSettings;
  @Deprecated('Use contractorCredentials')
  static const contractorDocuments = contractorCredentials;
  @Deprecated('Use contractorHome')
  static const contractorPaymentsAlias = contractorHome;
  @Deprecated('Use contractorProfile')
  static const contractorSwitchTenant = contractorProfile;
  @Deprecated('Use contractorSchedule')
  static const contractorTimetable = contractorSchedule;
  @Deprecated('Use contractorOnboarding')
  static const contractorEngagementAccept = contractorOnboarding;
}

/// Staff shell route names.
abstract final class StaffRoutes {
  StaffRoutes._();

  static const home = AppRoutes.staffHome;
  static const workforce = AppRoutes.staffWorkforce;
  static const clients = AppRoutes.staffClients;
  static const jobs = AppRoutes.staffJobs;
  static const visits = AppRoutes.staffVisits;
  static const payments = AppRoutes.staffPayments;
  static const compliance = AppRoutes.staffCompliance;
  static const settings = AppRoutes.staffSettings;

  static const List<String> all = [
    home,
    workforce,
    clients,
    jobs,
    visits,
    payments,
    compliance,
    settings,
  ];
}

/// Contractor shell route names.
abstract final class ContractorRoutes {
  ContractorRoutes._();

  static const home = AppRoutes.contractorHome;
  static const visits = AppRoutes.contractorVisits;
  static const visitDetail = AppRoutes.contractorVisitDetail;
  static const schedule = AppRoutes.contractorSchedule;
  static const credentials = AppRoutes.contractorCredentials;
  static const profile = AppRoutes.contractorProfile;
  static const onboarding = AppRoutes.contractorOnboarding;
  static const register = AppRoutes.contractorRegister;

  static const List<String> all = [
    home,
    visits,
    visitDetail,
    schedule,
    credentials,
    profile,
  ];
}

/// @Deprecated Use [StaffRoutes].
typedef AdminRoutes = StaffRoutes;
