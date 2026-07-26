/// Application-wide constants for networking and local storage keys.
abstract final class AppConstants {
  AppConstants._();

  /// API origin (no trailing slash). Override at compile time, e.g.
  /// `--dart-define=API_BASE_URL=http://localhost:8000`.
  /// Prefer [AppEnv.apiBaseUrl] for new code (also exposes billing/terms defines).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.rostiq.co',
  );

  static const String apiV1 = '/v1';

  // --- Auth (DOMAIN_V2) ---
  static const String authLoginPath = '$apiV1/auth/login';
  static const String authRefreshPath = '$apiV1/auth/refresh';
  static const String authLogoutPath = '$apiV1/auth/logout';
  static const String authMeContextPath = '$apiV1/auth/me/context';
  static const String authSwitchTenantPath = '$apiV1/auth/switch-tenant';
  static const String authCompleteFirstLoginPath =
      '$apiV1/auth/complete_first_login';
  static const String authUsersMePath = '$apiV1/auth/users/me';
  static const String mePath = '$apiV1/me';

  // --- Contractors / engagements ---
  static const String contractorsRegisterPath = '$apiV1/contractors/register';
  static const String contractorMePath = '$apiV1/contractor-me';
  static const String contractorMeEngagementsPath =
      '$apiV1/contractor-me/engagements';
  static const String contractorMeTimetablePath =
      '$apiV1/contractor-me/timetable';
  static const String contractorMeAvailabilityPath =
      '$apiV1/contractor-me/availability';
  static const String contractorMeLeavePath = '$apiV1/contractor-me/leave';
  static const String tenantEngagementsPath =
      '$apiV1/tenants/current/engagements';
  static const String engagementsPath = '$apiV1/engagements';

  // --- Tenant members / clients / forms / jobs / visits ---
  static const String tenantMembersPath = '$apiV1/tenant-members';
  static const String clientsPath = '$apiV1/clients';
  static const String formTemplatesPath = '$apiV1/form-templates';
  static const String jobsPath = '$apiV1/jobs';
  static const String visitsPath = '$apiV1/visits';

  // --- Documents ---
  static const String documentsUploadUrlPath = '$apiV1/documents/upload-url';
  static const String documentsPath = '$apiV1/documents';

  // --- Payments / rates / adjustments ---
  static const String paymentBatchesPath = '$apiV1/payment-batches';
  static const String engagementRatesPath = '$apiV1/payroll/engagement-rates';
  static const String attendanceAdjustmentsPath =
      '$apiV1/attendance/adjustments';

  // --- Branches / notifications ---
  static const String branchesPath = '$apiV1/branches';
  static const String notificationDevicesPath =
      '$apiV1/notifications/devices';
  static const String notificationEventsPath =
      '$apiV1/notifications/events';

  /// Attendance clock-in/out source (device GPS) — legacy punch flows.
  static const String attendanceSource = 'gps';

  // --- Deprecated / unmounted (expect 404) — do not use in new code ---

  @Deprecated('Unmounted V2 — use tenant-members')
  static const String verifyUserPath = '$apiV1/auth/verify_user';

  @Deprecated('Unmounted V2 — PIN kiosk removed')
  static const String verifyPinPath = '$apiV1/auth/verify_pin';

  @Deprecated('Unmounted V2 — PIN kiosk removed')
  static const String setPinPath = '$apiV1/auth/set_pin';

  @Deprecated('Unmounted V2 — use jobs/visits board')
  static const String schedulingBoardTodayPath =
      '$apiV1/scheduling/board/today';

  @Deprecated('Unmounted V2')
  static const String schedulingBoardPath = '$apiV1/scheduling/board';

  @Deprecated('Unmounted V2')
  static const String schedulingTemplatesPath = '$apiV1/scheduling/templates';

  @Deprecated('Unmounted V2')
  static const String schedulingAssignmentsPath =
      '$apiV1/scheduling/assignments';

  @Deprecated('Unmounted V2')
  static const String schedulingAssignmentsBulkPath =
      '$apiV1/scheduling/assignments/bulk';

  @Deprecated('Unmounted V2 — use contractor-me/leave')
  static const String schedulingLeavePath = '$apiV1/scheduling/leave';

  @Deprecated('Unmounted V2')
  static const String schedulingEmployeeSchedulesPath =
      '$apiV1/scheduling/employee-schedules';

  @Deprecated('Unmounted V2')
  static const String schedulingCopyWeekPath = '$apiV1/scheduling/copy-week';
}

/// Keys used with [GetStorage] for auth tokens.
abstract final class StorageKeys {
  StorageKeys._();

  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
}

/// Controllers must not call Dio directly — use repositories only (DOMAIN_V2).
abstract final class RepositoryOnlyRule {
  RepositoryOnlyRule._();

  static const message =
      'Ban: do not add new controller-level raw Dio calls; use repositories.';
}
