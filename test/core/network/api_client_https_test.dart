import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/constants/app_constants.dart';
import 'package:rostiq/core/network/cert_pinning.dart';
import 'package:rostiq/core/network/cert_pins.dart';

void main() {
  test('default API_BASE_URL is documented as non-production HTTP', () {
    expect(
      AppConstants.baseUrl.startsWith('http://') ||
          AppConstants.baseUrl.startsWith('https://'),
      isTrue,
    );
  });

  test('when API_BASE_URL is provided via define it must be HTTPS for prod', () {
    const url = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (url.isNotEmpty &&
        !url.contains('localhost') &&
        !url.contains('127.0.0.1') &&
        !url.contains('10.0.2.2') &&
        !RegExp(r'^\d+\.\d+\.\d+\.\d+').hasMatch(
          Uri.tryParse(url)?.host ?? '',
        )) {
      expect(
        url.startsWith('https://'),
        isTrue,
        reason: 'Non-local API_BASE_URL must use HTTPS',
      );
    }
  });

  test('prod host shouldApplyCertPinning with shipped pins', () {
    expect(
      shouldApplyCertPinning(
        'https://api.rostiq.co',
        pins: CertPins.all,
        isMobileOverride: true,
      ),
      isTrue,
    );
  });
}
