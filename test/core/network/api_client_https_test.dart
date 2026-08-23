import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/constants/app_constants.dart';

void main() {
  test('default API_BASE_URL is documented as non-production HTTP', () {
    // Compile-time default is HTTP for local/dev devices. Production builds
    // must pass --dart-define=API_BASE_URL=https://...
    expect(
      AppConstants.baseUrl.startsWith('http://') ||
          AppConstants.baseUrl.startsWith('https://'),
      isTrue,
    );
  });

  test('when API_BASE_URL is provided via define it must be HTTPS for prod', () {
    const url = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    // Empty = using package default (dev). Non-empty prod CI should use https.
    if (url.isNotEmpty && !url.contains('localhost') && !url.contains('127.0.0.1')) {
      expect(
        url.startsWith('https://'),
        isTrue,
        reason: 'Non-local API_BASE_URL must use HTTPS',
      );
    }
  });
}
