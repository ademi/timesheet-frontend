import 'package:dio/dio.dart';

import 'api_url_guard.dart';
import 'cert_pinning.dart';

/// Wires release HTTPS gate + SPKI pinning onto both Dio clients (F-fe-001 / D5).
void configureApiClientNetworking({
  required Dio plainDio,
  required Dio dio,
  required String baseUrl,
  required List<String> pins,
  required bool isRelease,
  bool? isMobileOverride,
}) {
  assertReleaseHttps(baseUrl, isRelease: isRelease);
  applyCertPinning(
    plainDio,
    baseUrl: baseUrl,
    pins: pins,
    isMobileOverride: isMobileOverride,
  );
  applyCertPinning(
    dio,
    baseUrl: baseUrl,
    pins: pins,
    isMobileOverride: isMobileOverride,
  );
}
