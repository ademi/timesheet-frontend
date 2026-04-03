/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  static const String baseUrl = 'http://localhost:9090';

  /// Attendance API (separate service).
  static const String attendanceBaseUrl = 'http://localhost:8000';

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
