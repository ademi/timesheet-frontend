/// F-fe-001 / eng-review D2: release builds must not use cleartext API URLs.
void assertReleaseHttps(String baseUrl, {required bool isRelease}) {
  if (!isRelease) return;
  if (baseUrl.startsWith('https://')) return;
  throw StateError(
    'Release builds require HTTPS API_BASE_URL (got: $baseUrl). '
    'Pass --dart-define=API_BASE_URL=https://api.rostiq.co',
  );
}
