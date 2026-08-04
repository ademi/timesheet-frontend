import 'app_constants.dart';

/// Canonical `/v1` path builders for the contractor domain (design §7).
///
/// Do not add legacy employee / scheduling / PIN paths here.
abstract final class ApiPaths {
  ApiPaths._();

  static const _v1 = AppConstants.apiV1;

  // Auth / session
  static const login = '$_v1/auth/login';
  static const refresh = '$_v1/auth/refresh';
  static const logout = '$_v1/auth/logout';
  static const switchTenant = '$_v1/auth/switch-tenant';
  static const meContext = '$_v1/auth/me/context';
  static const completeFirstLogin = '$_v1/auth/complete_first_login';
  static const usersMe = '$_v1/auth/users/me';
  static const me = '$_v1/me';

  // Contractors
  static const contractorsRegister = '$_v1/contractors/register';
  static String publicContractorInvite(String token) =>
      '$_v1/public/contractor-invites/$token';
  static const contractorMe = '$_v1/contractor-me';
  static const contractorMeEngagements = '$_v1/contractor-me/engagements';
  static const contractorMeCredentials = '$_v1/contractor-me/credentials';
  static String contractorMeCredential(String id) =>
      '$contractorMeCredentials/$id';
  static String contractorMeCredentialSupersede(String id) =>
      '${contractorMeCredential(id)}/supersede';
  static const contractorMePrivacyExport = '$_v1/contractor-me/privacy-export';
  static const contractorMeTimetable = '$_v1/contractor-me/timetable';
  static const contractorMeAvailability = '$_v1/contractor-me/availability';
  static const contractorMeLeave = '$_v1/contractor-me/leave';
  static String contractorMeLeaveItem(String id) => '$contractorMeLeave/$id';
  static const contractorMeSharingAccessRequests =
      '$_v1/contractor-me/sharing-access-requests';
  static String contractorMeSharingAccessRequestApprove(String id) =>
      '$contractorMeSharingAccessRequests/$id/approve';

  /// Credential category catalog (code + human-readable label).
  static const credentialCategories = '$_v1/credential-categories';

  // Engagements
  static const tenantEngagements = '$_v1/tenants/current/engagements';
  static String tenantContractorCredentials(String contractorId) =>
      '$_v1/tenants/current/contractors/$contractorId/credentials';
  static String engagement(String id) => '$_v1/engagements/$id';
  static String engagementAccept(String id) => '${engagement(id)}/accept';
  static String engagementApprove(String id) => '${engagement(id)}/approve';
  static String engagementActivate(String id) => '${engagement(id)}/activate';
  static String engagementApproveAndActivate(String id) =>
      '${engagement(id)}/approve-and-activate';
  static String engagementSuspend(String id) => '${engagement(id)}/suspend';
  static String engagementResume(String id) => '${engagement(id)}/resume';
  static String engagementEnd(String id) => '${engagement(id)}/end';
  static String engagementCredentialReviews(String id) =>
      '${engagement(id)}/credential-reviews';
  static String engagementSharingAccessRequests(String engagementId) =>
      '$tenantEngagements/$engagementId/sharing-access-requests';

  // Compliance
  static const legalDocumentsCurrent =
      '$_v1/compliance/legal-documents/current';
  /// Public register legal read (API-004). Query: `doc_key`.
  static const publicLegalDocumentsCurrent =
      '$_v1/public/legal-documents/current';
  static const collectionNotices = '$_v1/compliance/collection-notices';
  static const legalEvents = '$_v1/compliance/legal-events';
  static const rightsRequests = '$_v1/compliance/rights-requests';
  static String rightsRequest(String id) => '$rightsRequests/$id';
  static const accessHistory = '$_v1/compliance/access-history';
  static const incidents = '$_v1/compliance/incidents';
  static String incident(String id) => '$incidents/$id';

  // Documents
  static const documentsUploadUrl = '$_v1/documents/upload-url';
  static const documents = '$_v1/documents';
  static String documentFinalize(String id) => '$documents/$id/finalize';
  static String documentDownloadUrl(String id) => '$documents/$id/download-url';
  static String documentContent(String id) => '$documents/$id/content';

  // Clients
  static const clients = '$_v1/clients';
  static String client(String id) => '$clients/$id';
  static const clientTypes = '$clients/types';
  static String clientType(String id) => '$clientTypes/$id';
  static String clientTypeRequirements(String clientTypeId) =>
      '${clientType(clientTypeId)}/requirements';
  static String clientProfile(String id) => '${client(id)}/profile';
  static String clientProfileFact(String id, String requirementKey) =>
      '${clientProfile(id)}/$requirementKey';
  static String clientForm(String id, String formKey) =>
      '${client(id)}/forms/$formKey';
  static String clientLegal(String id, String legalKey) =>
      '${client(id)}/legal/$legalKey';
  static String clientLegalDocumentCurrent(String legalDocKey) =>
      '$clients/legal-documents/$legalDocKey/current';
  static String clientReadiness(String id) => '${client(id)}/readiness';
  static String clientDocumentShares(String id) =>
      '${client(id)}/document-shares';
  static String clientDocumentShare(String id, String shareId) =>
      '${clientDocumentShares(id)}/$shareId';
  static String clientSites(String id) => '${client(id)}/sites';
  static String clientSite(String id, String siteId) =>
      '${clientSites(id)}/$siteId';
  static String clientContacts(String id) => '${client(id)}/contacts';
  static String clientContact(String id, String contactId) =>
      '${clientContacts(id)}/$contactId';
  static String clientInvites(String id) => '${client(id)}/invites';
  static String publicClientInvite(String token) =>
      '$_v1/public/client-invites/$token';
  static String publicClientInviteAcknowledge(String token) =>
      '${publicClientInvite(token)}/acknowledge';
  /// Address → coordinates (Google Geocoding via backend; no auth).
  static const publicGeocode = '$_v1/public/geocode';

  // Forms / jobs / visits
  static const formTemplates = '$_v1/form-templates';
  static String formTemplate(String id) => '$formTemplates/$id';
  static const jobs = '$_v1/jobs';
  static String job(String id) => '$jobs/$id';
  static String jobFormCatalog(String id) => '${job(id)}/form-catalog';
  static String jobRecurrenceRules(String id) => '${job(id)}/recurrence-rules';
  static String jobRecurrenceRule(String id, String ruleId) =>
      '${jobRecurrenceRules(id)}/$ruleId';
  static String jobRecurrenceGenerate(String id, String ruleId) =>
      '${jobRecurrenceRule(id, ruleId)}/generate';
  static String jobVisits(String id) => '${job(id)}/visits';
  static const visits = '$_v1/visits';
  static String visit(String id) => '$visits/$id';
  static String visitCancel(String id) => '${visit(id)}/cancel';
  static String visitCheckIn(String id) => '${visit(id)}/check-in';
  static String visitComplete(String id) => '${visit(id)}/complete';
  static String visitTask(String id, String taskId) =>
      '${visit(id)}/tasks/$taskId';
  static String visitFormSubmissions(String id) =>
      '${visit(id)}/form-submissions';

  // Payroll / payments
  static String engagementRates(String engagementId) =>
      '$_v1/payroll/engagement-rates/$engagementId';
  static String engagementRate(String rateId) =>
      '$_v1/payroll/engagement-rates/$rateId';
  static const paymentBatches = '$_v1/payment-batches';
  static String paymentBatch(String id) => '$paymentBatches/$id';
  static String paymentBatchPost(String id) => '${paymentBatch(id)}/post';
  static String paymentBatchVoid(String id) => '${paymentBatch(id)}/void';

  // Tenants (settings: timezone / public_holiday_jurisdiction)
  static const tenants = '$_v1/tenants';
  static String tenant(String id) => '$tenants/$id';

  // Subscription / notifications / branches / members
  static const subscription = '$_v1/subscription';
  static const notificationDevices = '$_v1/notifications/devices';
  static String notificationDevice(String token) =>
      '$notificationDevices/$token';
  static const notificationEvents = '$_v1/notifications/events';
  static const notificationSettings = '$_v1/notifications/settings';
  static const branches = '$_v1/branches';
  static const tenantMembers = '$_v1/tenant-members';
  static String tenantMember(String id) => '$tenantMembers/$id';
}
