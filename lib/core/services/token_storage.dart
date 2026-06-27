import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../app/constants/scheduling_permissions.dart';

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

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedBranchId;
  String? _cachedBranchName;
  String? _cachedRole;

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;
  String? get branchId => _cachedBranchId;
  String? get branchName => _cachedBranchName;

  /// Selected portal role (e.g. `admin` / `attendance`). Persisted so a web
  /// refresh on a deep route can restore it instead of losing the in-memory value.
  String? get role => _cachedRole;

  /// Permission strings from the current access token JWT (`permissions` claim).
  List<String> get permissions => _readPermissionsFromToken();

  bool hasPermission(String permission) {
    final granted = permissions;
    if (granted.isEmpty) return false;
    if (granted.contains('*')) return true;
    return granted.contains(permission);
  }

  bool get canViewSchedule =>
      hasPermission(SchedulingPermissions.read) ||
      hasPermission(SchedulingPermissions.manage);

  bool get canManageSchedule => hasPermission(SchedulingPermissions.manage);

  Map<String, dynamic>? get _jwtPayload {
    final token = _cachedAccessToken;
    if (token == null || token.isEmpty) return null;
    try {
      return JWT.decode(token).payload;
    } catch (_) {
      return null;
    }
  }

  List<String> _readPermissionsFromToken() {
    final payload = _jwtPayload;
    if (payload == null) return const [];

    final raw = payload['permissions'];
    if (raw is List) {
      return raw.whereType<String>().toList();
    }
    return const [];
  }

  /// Call once at startup (before any API calls) to warm the in-memory cache.
  Future<void> loadFromStorage() async {
    _cachedAccessToken = await _storage.read(key: _keyAccess);
    _cachedRefreshToken = await _storage.read(key: _keyRefresh);
    _cachedBranchId = await _storage.read(key: _keyBranch);
    _cachedBranchName = await _storage.read(key: _keyBranchName);
    _cachedRole = await _storage.read(key: _keyRole);
  }

  Future<void> persistRole(String role) async {
    _cachedRole = role;
    await _storage.write(key: _keyRole, value: role);
  }

  /// Returns true if the stored access token expires within [thresholdSeconds].
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
    await _storage.deleteAll();
  }
}
