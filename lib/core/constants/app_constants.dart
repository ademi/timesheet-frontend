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
    defaultValue: 'http://11.0.0.98:8000',
  );

  /// Shared API version prefix for all versioned endpoints.
  static const String apiV1 = '/v1';

  /// Branches available to the authenticated admin user.
  static const String branchesPath = '$apiV1/branches';

  /// Auth: verify credentials before sensitive actions (e.g. attendance).
  static const String verifyUserPath = '$apiV1/auth/verify_user';

  /// Auth: verify 4-digit PIN before clock-in/out.
  static const String verifyPinPath = '$apiV1/auth/verify_pin';

  /// Auth: set initial PIN when none exists.
  static const String setPinPath = '$apiV1/auth/set_pin';

  /// Attendance clock-in/out source (device GPS).
  static const String attendanceSource = 'gps';

  /// Scheduling board — today roster.
  static const String schedulingBoardTodayPath =
      '$apiV1/scheduling/board/today';

  /// Scheduling board — week range grid.
  static const String schedulingBoardPath = '$apiV1/scheduling/board';

  /// Shift templates.
  static const String schedulingTemplatesPath = '$apiV1/scheduling/templates';

  /// Daily assignment overrides.
  static const String schedulingAssignmentsPath =
      '$apiV1/scheduling/assignments';

  /// Bulk daily assignments.
  static const String schedulingAssignmentsBulkPath =
      '$apiV1/scheduling/assignments/bulk';

  /// Employee leave records.
  static const String schedulingLeavePath = '$apiV1/scheduling/leave';

  /// Recurring employee schedules.
  static const String schedulingEmployeeSchedulesPath =
      '$apiV1/scheduling/employee-schedules';

  /// Copy week overrides.
  static const String schedulingCopyWeekPath = '$apiV1/scheduling/copy-week';
}

/// Keys used with [GetStorage] for auth tokens.
abstract final class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
}
