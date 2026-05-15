/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  /// API origin (no trailing slash). Override at compile time, e.g.
  /// `--dart-define=API_BASE_URL=http://10.0.2.2:8000` (Android emulator → host).
  ///
  /// Do not point [baseUrl] at a raw IP/IPv6 literal for **HTTPS** to the same
  /// Cloudflare host: TLS expects the certificate hostname, not an address.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://timesheetbackend.deepdownidea.com',
  );

  /// Shared API version prefix for all versioned endpoints.
  static const String apiV1 = '/v1';

  /// Auth: verify credentials before sensitive actions (e.g. attendance).
  static const String verifyUserPath = '$apiV1/auth/verify_user';

  /// Fixed tenant identifier sent with every login request.
  static const String tenantId = 'a0000002-0001-4001-8001-000000000001';

  /// Fixed branch filter for employee list.
  static const String branchId = 'a0000002-0001-4001-8001-000000000002';

  /// Attendance clock-in/out source (device GPS).
  static const String attendanceSource = 'gps';
}

/// Keys used with [GetStorage] for auth tokens.
abstract final class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
}
