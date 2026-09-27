import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';

/// Shell-tab permission requirements (mirrors GetX [PermissionGuard] on those pages).
///
/// Used by go_router redirects on web. Empty `anyOf` means actor/auth only.
class ShellTabPermission {
  const ShellTabPermission(this.anyOf);
  final List<String> anyOf;
}

/// Exact shell-tab path → permission gate.
const Map<String, ShellTabPermission> kShellTabPermissions = {
  AppRoutes.staffHome: ShellTabPermission([AppPermissions.authSession]),
  AppRoutes.staffVisits: ShellTabPermission([
    AppPermissions.shiftsRead,
    AppPermissions.shiftsManage,
    AppPermissions.visitsRead,
    AppPermissions.visitsManage,
    AppPermissions.jobsManage,
  ]),
  AppRoutes.staffClients: ShellTabPermission([AppPermissions.clientsRead]),
  AppRoutes.staffWorkforce: ShellTabPermission([
    AppPermissions.contractorsRead,
  ]),
  AppRoutes.staffAttendanceReview: ShellTabPermission([
    AppPermissions.attendanceAdjust,
    AppPermissions.visitsManage,
  ]),
  AppRoutes.staffPayments: ShellTabPermission([
    AppPermissions.paymentsView,
    AppPermissions.paymentsManage,
  ]),
  AppRoutes.staffBillingExports: ShellTabPermission([
    AppPermissions.billingView,
    AppPermissions.billingManage,
  ]),
  AppRoutes.staffCompliance: ShellTabPermission([
    AppPermissions.credentialsReview,
    AppPermissions.complianceRightsManage,
    AppPermissions.complianceIncidentsManage,
    AppPermissions.complianceAuditView,
  ]),
  AppRoutes.staffSettings: ShellTabPermission([AppPermissions.authSession]),
  // Contractor shell tabs: actor gate only (no extra permission list).
  AppRoutes.contractorHome: ShellTabPermission([]),
  AppRoutes.contractorVisits: ShellTabPermission([]),
  AppRoutes.contractorSchedule: ShellTabPermission([]),
  AppRoutes.contractorCredentials: ShellTabPermission([]),
  AppRoutes.contractorProfile: ShellTabPermission([]),
};
