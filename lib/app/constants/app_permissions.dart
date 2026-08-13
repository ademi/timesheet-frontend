/// RBAC permission keys for DOMAIN_V2 (JWT `permissions` claim).
///
/// Catalog: docs/migration/phase1/app-permissions-catalog.md
abstract final class AppPermissions {
  AppPermissions._();

  static const authSession = 'auth.session';

  static const tenantsRead = 'tenants.read';
  static const tenantsManage = 'tenants.manage';

  static const tenantMembersRead = 'tenant_members.read';
  static const tenantMembersManage = 'tenant_members.manage';

  static const contractorsRead = 'contractors.read';
  static const contractorsInvite = 'contractors.invite';
  static const contractorsApprove = 'contractors.approve';
  static const contractorsManage = 'contractors.manage';
  static const contractorsDocsRead = 'contractors.docs.read';

  static const clientsRead = 'clients.read';
  static const clientsManage = 'clients.manage';
  static const clientsTypesRead = 'clients.types.read';
  static const clientsProfileManage = 'clients.profile.manage';
  static const clientsLegalAccept = 'clients.legal.accept';
  static const clientsDocsManage = 'clients.docs.manage';
  static const clientsDocsShare = 'clients.docs.share';
  static const clientsReadinessRead = 'clients.readiness.read';

  static const jobsRead = 'jobs.read';
  static const jobsManage = 'jobs.manage';

  static const visitsRead = 'visits.read';
  static const visitsManage = 'visits.manage';
  static const visitsCheckIn = 'visits.check_in';
  static const visitsComplete = 'visits.complete';

  static const shiftsRead = 'shifts.read';
  static const shiftsManage = 'shifts.manage';
  static const shiftsClaim = 'shifts.claim';

  static const documentsUpload = 'documents.upload';

  static const paymentsView = 'payments.view';
  static const paymentsManage = 'payments.manage';
  static const paymentsViewOwn = 'payments.view_own';

  static const attendanceAdjust = 'attendance.adjust';

  static const notificationsReceive = 'notifications.receive';
  static const notificationsManage = 'notifications.manage';

  static const contractorScheduleManage = 'contractor.schedule.manage';

  static const branchesRead = 'branches.read';
  static const branchesManage = 'branches.manage';

  static const auditView = 'audit.view';
  static const rbacManage = 'rbac.manage';

  /// Landing-page billing only — do not build Flutter subscription UI.
  static const subscriptionView = 'subscription.view';
  static const subscriptionManage = 'subscription.manage';
  static const billingView = 'billing.view';

  static const credentialsRead = 'credentials.read';
  static const credentialsManage = 'credentials.manage';
  static const credentialsReview = 'credentials.review';
  static const credentialsSourceRead = 'credentials.source.read';

  static const complianceLegalRead = 'compliance.legal.read';
  static const complianceLegalAccept = 'compliance.legal.accept';
  static const complianceConsentManage = 'compliance.consent.manage';
  static const complianceRightsManage = 'compliance.rights.manage';
  static const complianceIncidentsManage = 'compliance.incidents.manage';
  static const complianceAuditView = 'compliance.audit.view';

  /// Superuser — UI gates treat as all permissions (mirror backend).
  static const platformAdmin = 'platform.admin';
}
