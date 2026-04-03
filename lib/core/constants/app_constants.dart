/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  static const String baseUrl = 'http://localhost:9090';

  /// Fixed tenant identifier sent with every login request.
  static const String tenantId = 'e4db72d4-13c3-4337-ab79-f4207f9fc0bf';
}

/// Keys used with [GetStorage] for auth tokens.
abstract final class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
}
