/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  /// Default API origin when no dart-define is set (timesheet-backend: `/v1`, `/v1/auth`, …).
  static const String _defaultApiOrigin = 'http://43.224.181.222:8080';

  /// Base URL for auth-only [ApiClient] (`/v1/auth/login`, refresh, logout, change_password).
  ///
  /// Override with `--dart-define=AUTH_BASE_URL=http://host:port` if auth is proxied elsewhere.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('AUTH_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _defaultApiOrigin;
  }

  /// Auth: verify credentials before sensitive actions (e.g. attendance).
  static const String verifyUserPath = '/v1/auth/verify_user';

  /// Base URL for [AttendanceApiClient] — same monolith as [baseUrl] by default.
  ///
  /// Override with `--dart-define=ATTENDANCE_BASE_URL=http://...:8080` when needed.
  static String get attendanceBaseUrl {
    const fromEnv = String.fromEnvironment(
      'ATTENDANCE_BASE_URL',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) return fromEnv;
    return _defaultApiOrigin;
  }

  /// Fixed tenant identifier sent with every login request.
  static const String tenantId = 'a0000001-0001-4001-8001-000000000001';

  /// Fixed branch filter for employee list.
  static const String branchId = 'a0000001-0001-4001-8001-000000000002';

  /// Attendance clock-in/out source (device GPS).
  static const String attendanceSource = 'gps';
}

/// Keys used with [GetStorage] for auth tokens.
abstract final class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
}
