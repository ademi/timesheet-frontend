import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/network/cert_pinning.dart';
import 'package:rostiq/core/network/cert_pins.dart';

void main() {
  test('shouldApplyCertPinning is false for HTTP URLs', () {
    expect(
      shouldApplyCertPinning(
        'http://11.0.0.98:8000',
        isMobileOverride: true,
      ),
      isFalse,
    );
    expect(
      shouldApplyCertPinning(
        'http://localhost:8000',
        isMobileOverride: true,
      ),
      isFalse,
    );
  });

  test('shouldApplyCertPinning is true for HTTPS URLs when pins present', () {
    expect(
      shouldApplyCertPinning(
        'https://api.rostiq.co',
        pins: CertPins.all,
        isMobileOverride: true,
      ),
      isTrue,
    );
  });

  test('shouldApplyCertPinning is false on non-mobile even with HTTPS pins', () {
    expect(
      shouldApplyCertPinning(
        'https://api.rostiq.co',
        pins: CertPins.all,
        isMobileOverride: false,
      ),
      isFalse,
    );
  });

  test('shouldApplyCertPinning is false when pins empty or placeholder', () {
    expect(
      shouldApplyCertPinning(
        'https://api.rostiq.co',
        pins: const ['PASTE_BASE64_SPKI_PIN_HERE'],
        isMobileOverride: true,
      ),
      isFalse,
    );
    expect(
      shouldApplyCertPinning(
        'https://api.rostiq.co',
        pins: const [],
        isMobileOverride: true,
      ),
      isFalse,
    );
  });

  test('applyCertPinning is a no-op when shouldApply is false', () {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
    final before = dio.httpClientAdapter;
    applyCertPinning(
      dio,
      baseUrl: 'http://localhost:8000',
      pins: CertPins.all,
      isMobileOverride: true,
    );
    expect(identical(dio.httpClientAdapter, before), isTrue);
  });

  test('applyCertPinning replaces adapter for HTTPS + real pins', () {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.rostiq.co'));
    applyCertPinning(
      dio,
      baseUrl: 'https://api.rostiq.co',
      pins: CertPins.all,
      isMobileOverride: true,
    );
    // Adapter instance may be same object if we mutate createHttpClient;
    // assert the callback is wired by making a type check + non-null createHttpClient.
    final adapter = dio.httpClientAdapter as IOHttpClientAdapter;
    expect(adapter.createHttpClient, isNotNull);
  });
}
