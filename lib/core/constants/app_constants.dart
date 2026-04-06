import 'package:flutter/foundation.dart';

/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  /// Auth API base URL (Phase 2 `ApiClient` / `plainDio`).
  ///
  /// **Do not use `0.0.0.0` here** — that is only for binding a server, not for
  /// clients to connect to.
  ///
  /// Defaults:
  /// - **Android emulator (AVD)** → `http://10.0.2.2:9090` (**not** `127.0.0.1`;
  ///   inside the emulator, `127.0.0.1` is the emulator itself, not your PC).
  /// - **Genymotion** → often `http://10.0.3.2:9090` (use `AUTH_BASE_URL` override).
  /// - **iOS simulator / Windows / macOS / Linux** → `127.0.0.1`.
  ///
  /// Optional: `adb reverse tcp:9090 tcp:9090` then you can point the app at
  /// `http://127.0.0.1:9090` if you override `AUTH_BASE_URL` accordingly.
  /// - **Physical phone** → run with
  ///   `--dart-define=AUTH_BASE_URL=http://YOUR_PC_LAN_IP:9090`
  ///   (e.g. `192.168.1.10`).
  ///
  /// Ensure the auth backend is running and listening (e.g. on port 9090).
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('AUTH_BASE_URL', defaultValue: '');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) return 'http://localhost:9090';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://11.0.0.176:9090';
      default:
        return 'http://11.0.0.176:9090';
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
    if (kIsWeb) return 'http://localhost:8000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://11.0.0.176:8000';
      default:
        return 'http://11.0.0.176:8000';
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
