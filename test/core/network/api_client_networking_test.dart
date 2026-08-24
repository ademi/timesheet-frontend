import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/network/api_client_networking.dart';
import 'package:rostiq/core/network/cert_pins.dart';

void main() {
  test('configureApiClientNetworking pins both Dios on HTTPS mobile', () {
    final plain = Dio(BaseOptions(baseUrl: 'https://api.rostiq.co'));
    final auth = Dio(BaseOptions(baseUrl: 'https://api.rostiq.co'));

    configureApiClientNetworking(
      plainDio: plain,
      dio: auth,
      baseUrl: 'https://api.rostiq.co',
      pins: CertPins.all,
      isRelease: true,
      isMobileOverride: true,
    );

    expect(
      (plain.httpClientAdapter as IOHttpClientAdapter).createHttpClient,
      isNotNull,
    );
    expect(
      (auth.httpClientAdapter as IOHttpClientAdapter).createHttpClient,
      isNotNull,
    );
  });

  test('configureApiClientNetworking throws on HTTP release', () {
    final plain = Dio();
    final auth = Dio();
    expect(
      () => configureApiClientNetworking(
        plainDio: plain,
        dio: auth,
        baseUrl: 'http://11.0.0.98:8000',
        pins: CertPins.all,
        isRelease: true,
        isMobileOverride: true,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
