import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/constants/app_permissions.dart';
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
  static const _keyLastTenantId = 'last_tenant_id';
  static const _keyLastEngagementId = 'last_engagement_id';

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedBranchId;
  String? _cachedBranchName;
  String? _cachedLastTenantId;
  String? _cachedLastEngagementId;
  int _sessionEpoch = 0;

  /// Bumps on [clear] / [persist] so a superseded writer can detect replacement.
  int get sessionEpoch => _sessionEpoch;

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;

  bool get hasRefreshToken =>
      _cachedRefreshToken != null && _cachedRefreshToken!.isNotEmpty;

  DateTime? get accessTokenExpiresAt {
    final payload = _jwtPayload;
    if (payload == null) return null;
    final exp = _readExpSeconds(payload['exp']);
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
  }

  /// True when a non-empty access token decodes and is not past its `exp`.
  bool get hasValidAccessToken {
    final token = _cachedAccessToken;
    if (token == null || token.isEmpty) return false;
    if (_jwtPayload == null) return false;
    final expiresAt = accessTokenExpiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isBefore(expiresAt);
  }

  bool get needsSessionRefresh => !hasValidAccessToken && hasRefreshToken;

  /// True when the user can stay on a protected route and recover via refresh.
  bool get canAttemptAuth => hasValidAccessToken || hasRefreshToken;
  String? get branchId => _cachedBranchId;
  String? get branchName => _cachedBranchName;

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

  bool get canViewSchedule =>
      hasPermission(AppPermissions.jobsRead) ||
      hasPermission(AppPermissions.visitsRead) ||
      hasPermission(AppPermissions.visitsManage);

  bool get canManageSchedule =>
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
    _cachedLastTenantId = await _storage.read(key: _keyLastTenantId);
    _cachedLastEngagementId = await _storage.read(key: _keyLastEngagementId);
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
    } else {
      _cachedLastEngagementId = null;
      await _storage.delete(key: _keyLastEngagementId);
    }
  }

  Future<void> clearLastTenantSelection() async {
    _cachedLastTenantId = null;
    _cachedLastEngagementId = null;
    await _storage.delete(key: _keyLastTenantId);
    await _storage.delete(key: _keyLastEngagementId);
  }

  Future<void> clearBranchSelection() async {
    _cachedBranchId = null;
    _cachedBranchName = null;
    await _storage.delete(key: _keyBranch);
    await _storage.delete(key: _keyBranchName);
  }

  bool needsProactiveRefresh({int thresholdSeconds = 300}) {
    final expiresAt = accessTokenExpiresAt;
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(
      expiresAt.subtract(Duration(seconds: thresholdSeconds)),
    );
  }

  int? _readExpSeconds(Object? exp) {
    if (exp is int) return exp;
    if (exp is num) return exp.toInt();
    return null;
  }

  /// Replaces the persisted session. Increments [sessionEpoch] so an in-flight
  /// refresh for the previous tenant cannot write those tokens back.
  Future<void> persist({
    required String accessToken,
    required String refreshToken,
    String? branchId,
  }) async {
    _sessionEpoch++;
    await persistTokens(accessToken: accessToken, refreshToken: refreshToken);
    if (branchId != null) {
      await persistBranchId(branchId);
    } else {
      await clearBranchSelection();
    }
    await clearLastTenantSelection();
  }

  Future<void> persistTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final epoch = _sessionEpoch;
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    if (epoch != _sessionEpoch) return;
    await _storage.write(key: _keyAccess, value: accessToken);
    if (epoch != _sessionEpoch) return;
    await _storage.write(key: _keyRefresh, value: refreshToken);
  }

  /// Persists rotated tokens only when [expectedRefreshToken] is still current.
  ///
  /// Returns false when logout / login / switch-tenant already replaced the
  /// session; the caller must not treat that as a restore of the old tenant.
  Future<bool> persistTokensIfCurrentRefresh({
    required String expectedRefreshToken,
    required String accessToken,
    required String refreshToken,
  }) async {
    if (_cachedRefreshToken != expectedRefreshToken) return false;
    await persistTokens(accessToken: accessToken, refreshToken: refreshToken);
    return _cachedRefreshToken == refreshToken;
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
    _sessionEpoch++;
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedBranchId = null;
    _cachedBranchName = null;
    _cachedLastTenantId = null;
    _cachedLastEngagementId = null;
    // Delete only auth keys. `deleteAll()` on web wipes every localStorage
    // entry, including GetStorage, and can race with a later session write.
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
    await _storage.delete(key: _keyBranch);
    await _storage.delete(key: _keyBranchName);
    await _storage.delete(key: _keyLastTenantId);
    await _storage.delete(key: _keyLastEngagementId);
  }
}
