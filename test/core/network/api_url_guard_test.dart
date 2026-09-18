import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/network/api_url_guard.dart';

void main() {
  test('assertReleaseHttps allows HTTPS in release', () {
    expect(
      () => assertReleaseHttps(
        'https://api.rostiq.co',
        isRelease: true,
      ),
      returnsNormally,
    );
  });

  test('assertReleaseHttps allows HTTP in non-release', () {
    expect(
      () => assertReleaseHttps(
        'http://11.0.0.98:8000',
        isRelease: false,
      ),
      returnsNormally,
    );
  });

  test('assertReleaseHttps throws on HTTP in release', () {
    expect(
      () => assertReleaseHttps(
        'http://11.0.0.98:8000',
        isRelease: true,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
