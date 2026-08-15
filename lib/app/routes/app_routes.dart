abstract class AppRoutes {
  static const gateway = '/gateway';
  static const login = '/login';
  static const firstLogin = '/first-login';
  static const adminBranchGateway = '/admin/branches';

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
  static const staffOngoingSupport = '/staff/jobs/ongoing-support';
  static const staffJobDetail = '/staff/jobs/detail';
  static const staffRecurrenceRuleForm = '/staff/jobs/recurrence-rule-form';
  static const staffFormTemplates = '/staff/jobs/form-templates';
  static const staffJobManageTemplates = '/staff/jobs/manage-templates';
  static const staffFormTemplateEditor = '/staff/jobs/form-template-editor';
  static const staffVisits = '/staff/visits';
  static const staffVisitDetail = '/staff/visits/detail';
  static const staffShiftDetail = '/staff/visits/shift-detail';
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
