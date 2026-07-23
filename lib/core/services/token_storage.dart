import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/constants/scheduling_permissions.dart';
import '../auth/jwt_claims.dart';

/// Single source of truth for persisting and reading auth tokens.
/// Uses flutter_secure_storage (iOS Keychain / Android Keystore).
class TokenStorage {
  TokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyBranch = 'branch_id';
  static const _keyBranchName = 'branch_name';
  static const _keyRole = 'user_role';
  static const _keyLastTenantId = 'last_tenant_id';
  static const _keyLastEngagementId = 'last_engagement_id';

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedBranchId;
  String? _cachedBranchName;
  String? _cachedRole;
  String? _cachedLastTenantId;
  String? _cachedLastEngagementId;

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;
  String? get branchId => _cachedBranchId;
  String? get branchName => _cachedBranchName;

  /// Legacy portal role (`admin` / `attendance`). Cleared on DOMAIN_V2 cutover.
  String? get role => _cachedRole;

  String? get lastTenantId => _cachedLastTenantId;
  String? get lastEngagementId => _cachedLastEngagementId;

  List<String> get permissions => jwtClaims?.permissions ?? const [];

  JwtClaims? get jwtClaims {
    final payload = _jwtPayload;
    if (payload == null) return null;
    return JwtClaims.fromPayload(payload);
  }

  bool hasPermission(String permission) {
    return jwtClaims?.hasPermission(permission) ?? false;
  }

  /// Legacy scheduling.* **or** V2 jobs/visits read.
  bool get canViewSchedule =>
      hasPermission(SchedulingPermissions.read) ||
      hasPermission(SchedulingPermissions.manage) ||
      hasPermission(AppPermissions.jobsRead) ||
      hasPermission(AppPermissions.visitsRead) ||
      hasPermission(AppPermissions.visitsManage);

  bool get canManageSchedule =>
      hasPermission(SchedulingPermissions.manage) ||
      hasPermission(AppPermissions.jobsManage) ||
      hasPermission(AppPermissions.visitsManage);

  Map<String, dynamic>? get _jwtPayload {
    final token = _cachedAccessToken;
    if (token == null || token.isEmpty) return null;
    try {
      final payload = JWT.decode(token).payload;
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) {
        return payload.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadFromStorage() async {
    _cachedAccessToken = await _storage.read(key: _keyAccess);
    _cachedRefreshToken = await _storage.read(key: _keyRefresh);
    _cachedBranchId = await _storage.read(key: _keyBranch);
    _cachedBranchName = await _storage.read(key: _keyBranchName);
    _cachedRole = await _storage.read(key: _keyRole);
    _cachedLastTenantId = await _storage.read(key: _keyLastTenantId);
    _cachedLastEngagementId = await _storage.read(key: _keyLastEngagementId);
  }

  Future<void> persistRole(String role) async {
    _cachedRole = role;
    await _storage.write(key: _keyRole, value: role);
  }

  Future<void> persistLastTenantSelection({
    required String tenantId,
    String? engagementId,
  }) async {
    _cachedLastTenantId = tenantId;
    await _storage.write(key: _keyLastTenantId, value: tenantId);
    if (engagementId != null) {
      _cachedLastEngagementId = engagementId;
      await _storage.write(key: _keyLastEngagementId, value: engagementId);
    }
  }

  bool needsProactiveRefresh({int thresholdSeconds = 300}) {
    final payload = _jwtPayload;
    if (payload == null) return false;
    try {
      final exp = payload['exp'];
      if (exp is! int) return false;
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      return DateTime.now().toUtc().isAfter(
            expiresAt.subtract(Duration(seconds: thresholdSeconds)),
          );
    } catch (_) {
      return false;
    }
  }

  Future<void> persist({
    required String accessToken,
    required String refreshToken,
    String? branchId,
  }) async {
    await persistTokens(accessToken: accessToken, refreshToken: refreshToken);
    if (branchId != null) {
      await persistBranchId(branchId);
    }
  }

  Future<void> persistTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    await _storage.write(key: _keyAccess, value: accessToken);
    await _storage.write(key: _keyRefresh, value: refreshToken);
  }

  Future<void> persistBranchId(String branchId) async {
    _cachedBranchId = branchId;
    await _storage.write(key: _keyBranch, value: branchId);
  }

  Future<void> persistBranchSelection({
    required String branchId,
    required String branchName,
  }) async {
    _cachedBranchId = branchId;
    _cachedBranchName = branchName;
    await _storage.write(key: _keyBranch, value: branchId);
    await _storage.write(key: _keyBranchName, value: branchName);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedBranchId = null;
    _cachedBranchName = null;
    _cachedRole = null;
    _cachedLastTenantId = null;
    _cachedLastEngagementId = null;
    await _storage.deleteAll();
  }
}
