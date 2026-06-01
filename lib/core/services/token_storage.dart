import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  String? _cachedAccessToken;
  String? _cachedRefreshToken;
  String? _cachedBranchId;

  String? get accessToken => _cachedAccessToken;
  String? get refreshToken => _cachedRefreshToken;
  String? get branchId => _cachedBranchId;

  /// Call once at startup (before any API calls) to warm the in-memory cache.
  Future<void> loadFromStorage() async {
    _cachedAccessToken = await _storage.read(key: _keyAccess);
    _cachedRefreshToken = await _storage.read(key: _keyRefresh);
    _cachedBranchId = await _storage.read(key: _keyBranch);
  }

  /// Returns true if the stored access token expires within [thresholdSeconds].
  bool needsProactiveRefresh({int thresholdSeconds = 300}) {
    final token = _cachedAccessToken;
    if (token == null) return false;
    try {
      final jwt = JWT.decode(token);
      final exp = jwt.payload['exp'];
      if (exp is! int) return false;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
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
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
    if (branchId != null) _cachedBranchId = branchId;
    await _storage.write(key: _keyAccess, value: accessToken);
    await _storage.write(key: _keyRefresh, value: refreshToken);
    if (branchId != null) await _storage.write(key: _keyBranch, value: branchId);
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    _cachedBranchId = null;
    await _storage.deleteAll();
  }
}
