import '../data/models/auth/auth_token_model.dart';
import '../routes/app_routes.dart';

/// Parsed cross-origin registration handoff from the landing page URL hash.
///
/// Landing builds: `{app}/admin-panel#access_token=…&refresh_token=…&…`
/// or `{app}/change-password#…` when [adminMustChangePassword] is true.
class LandingAuthHandoff {
  const LandingAuthHandoff({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.tenantId,
    required this.adminMustChangePassword,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String? tenantId;
  final bool adminMustChangePassword;

  AuthTokenModel toAuthTokens() {
    return AuthTokenModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: tokenType,
      mustChangePassword: adminMustChangePassword,
    );
  }
}

/// True for landing → admin-app paths that carry hash tokens.
bool isLandingAuthHandoffPath(String path) {
  return path == AppRoutes.adminPanel || path == AppRoutes.changePassword;
}

/// Parses `access_token=…&refresh_token=…` style fragments (with or without `#`).
LandingAuthHandoff? parseLandingAuthHandoffFragment(String? fragment) {
  if (fragment == null || fragment.isEmpty) return null;

  final raw = fragment.startsWith('#') ? fragment.substring(1) : fragment;
  if (raw.isEmpty) return null;

  final params = Uri.splitQueryString(raw);
  final access = params['access_token']?.trim() ?? '';
  if (access.isEmpty) return null;

  final refresh = params['refresh_token']?.trim() ?? '';
  final tokenType = (params['token_type']?.trim().isNotEmpty ?? false)
      ? params['token_type']!.trim()
      : 'bearer';
  final tenantId = params['tenant_id']?.trim();
  final mustChange = _parseBool(params['admin_must_change_password']);

  return LandingAuthHandoff(
    accessToken: access,
    refreshToken: refresh,
    tokenType: tokenType,
    tenantId: (tenantId == null || tenantId.isEmpty) ? null : tenantId,
    adminMustChangePassword: mustChange,
  );
}

bool _parseBool(String? raw) {
  if (raw == null) return false;
  switch (raw.trim().toLowerCase()) {
    case '1':
    case 'true':
    case 'yes':
      return true;
    default:
      return false;
  }
}
