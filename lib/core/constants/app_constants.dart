/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  /// Unified API base URL for local development.
  static const String baseUrl = 'http://0.0.0.0:8000';

  /// Shared API version prefix for all versioned endpoints.
  static const String apiV1 = '/v1';

  /// Auth: verify credentials before sensitive actions (e.g. attendance).
  static const String verifyUserPath = '$apiV1/auth/verify_user';

  /// Fixed tenant identifier sent with every login request.
  static const String tenantId = 'e4db72d4-13c3-4337-ab79-f4207f9fc0bf';

  /// Fixed branch filter for employee list.
  static const String branchId = 'eb28fc2c-96c0-45a6-bae2-1699c8b7809e';

  /// Attendance clock-in/out source (device GPS).
  static const String attendanceSource = 'gps';
}

/// Keys used with [GetStorage] for auth tokens.
abstract final class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
}
