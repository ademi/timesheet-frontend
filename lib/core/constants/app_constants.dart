import 'package:flutter/foundation.dart';

/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  static String get baseUrl {
    const fromEnv = String.fromEnvironment('AUTH_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://43.224.181.222:9090';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://43.224.181.222:9090';
      default:
        return 'http://43.224.181.222:9090';
    }
  }

  /// Auth: verify credentials before sensitive actions (e.g. attendance).
  static const String verifyUserPath = '/auth/verify_user';

  /// Attendance API base URL (Phase 3 `AttendanceApiClient`).
  ///
  /// Override with `--dart-define=ATTENDANCE_BASE_URL=http://...:8000` when needed.
  static String get attendanceBaseUrl {
    const fromEnv = String.fromEnvironment(
      'ATTENDANCE_BASE_URL',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://43.224.181.222:8000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://43.224.181.222:8000';
      default:
        return 'http://43.224.181.222:8000';
    }
  }

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
