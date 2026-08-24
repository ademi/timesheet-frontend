import 'package:rostiq/core/constants/app_constants.dart';

/// Compile-time environment / feature defines for the contractor platform.
abstract final class AppEnv {
  AppEnv._();

  /// Same compile-time origin as [AppConstants.baseUrl] (single dart-define).
  static const String apiBaseUrl = AppConstants.baseUrl;

  /// Landing GoCardless / billing page (subscription CTA).
  static const String billingUrl = String.fromEnvironment(
    'BILLING_URL',
    defaultValue: 'https://rostiq.co/billing',
  );

  /// Optional provider company signup on landing.
  static const String landingUrl = String.fromEnvironment(
    'LANDING_URL',
    defaultValue: 'https://rostiq.co/signup',
  );

  /// Must match DB `platform_terms` current version for public register.
  /// Local seed default: `v0.1-placeholder` (timesheet-db seed 011).
  static const String termsVersion = String.fromEnvironment(
    'TERMS_VERSION',
    defaultValue: 'v0.1-placeholder',
  );

  /// Must match DB `privacy_policy` current version for public register.
  static const String privacyVersion = String.fromEnvironment(
    'PRIVACY_VERSION',
    defaultValue: 'v0.1-placeholder',
  );
}
