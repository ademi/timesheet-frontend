/// Decoded access-token claims for the V2 actor model.
///
/// Source of truth for permissions is the JWT (`permissions` claim).
/// Do not trust client-forged values for authorization — the server re-checks.
class JwtClaims {
  const JwtClaims({
    required this.sub,
    required this.tenantId,
    required this.permissions,
    required this.actorType,
    required this.iat,
    required this.exp,
    this.typ = 'access',
    this.contractorId,
    this.tenantMemberId,
    this.mustChangePassword = false,
  });

  final String sub;
  final String? tenantId;
  final List<String> permissions;
  final String? actorType;
  final int? iat;
  final int? exp;
  final String? typ;
  final String? contractorId;
  final String? tenantMemberId;

  /// JWT may include `mcp: true` when password must change.
  final bool mustChangePassword;

  bool get isTenantMember => actorType == 'tenant_member';
  bool get isContractor => actorType == 'contractor';

  bool hasPermission(String permission) {
    if (permissions.isEmpty) return false;
    if (permissions.contains('*')) return true;
    return permissions.contains(permission);
  }

  factory JwtClaims.fromPayload(Map<String, dynamic> payload) {
    return JwtClaims(
      sub: payload['sub']?.toString() ?? '',
      tenantId: payload['tenant_id']?.toString(),
      permissions: _readStringList(payload['permissions']),
      actorType: payload['actor_type']?.toString(),
      iat: _readInt(payload['iat']),
      exp: _readInt(payload['exp']),
      typ: payload['typ']?.toString() ?? 'access',
      contractorId: payload['contractor_id']?.toString(),
      tenantMemberId: payload['tenant_member_id']?.toString(),
      mustChangePassword: payload['mcp'] == true,
    );
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<String>().toList(growable: false);
  }

  static int? _readInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }
}
