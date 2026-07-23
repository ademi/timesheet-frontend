/// Compile-time feature flags for the contractor-era (DOMAIN_V2) migration.
///
/// Enable with: `--dart-define=DOMAIN_V2=true`
/// Disable legacy portal split with the same flag (default **true** while
/// targeting the V2 API at localhost / cutover binaries).
abstract final class FeatureFlags {
  FeatureFlags._();

  static const String _domainV2Raw = String.fromEnvironment(
    'DOMAIN_V2',
    defaultValue: 'true',
  );

  /// When true: actor-based dual shells, SessionController, V2 paths.
  /// When false: legacy gateway attendance/admin portal role flow.
  static bool get domainV2 {
    final v = _domainV2Raw.toLowerCase().trim();
    return v == 'true' || v == '1' || v == 'yes';
  }
}
