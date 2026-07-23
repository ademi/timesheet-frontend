import '../auth/jwt_claims.dart';
import '../services/token_storage.dart';
import '../../app/constants/app_permissions.dart';

/// Shared permission helpers over JWT claims / [TokenStorage].
abstract final class PermissionHelpers {
  PermissionHelpers._();

  static bool hasPermission(TokenStorage storage, String permission) {
    return storage.hasPermission(permission);
  }

  static bool hasAny(TokenStorage storage, Iterable<String> permissions) {
    for (final p in permissions) {
      if (storage.hasPermission(p)) return true;
    }
    return false;
  }

  static bool hasPermissionInClaims(JwtClaims? claims, String permission) {
    return claims?.hasPermission(permission) ?? false;
  }

  static bool canManageTeam(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.tenantMembersManage);

  static bool canReadTeam(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.tenantMembersRead);

  static bool canReadContractors(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.contractorsRead);

  static bool canReadClients(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.clientsRead);

  static bool canReadJobs(TokenStorage storage) =>
      hasAny(storage, [AppPermissions.jobsRead, AppPermissions.visitsRead]);

  static bool canViewPayments(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.paymentsView);

  static bool canCheckIn(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.visitsCheckIn);

  static bool canUploadDocuments(TokenStorage storage) =>
      hasPermission(storage, AppPermissions.documentsUpload);
}
