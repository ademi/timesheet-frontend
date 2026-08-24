import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http_security_pinning/http_security_pinning.dart';

bool shouldApplyCertPinning(
  String baseUrl, {
  List<String> pins = const [],
  bool? isMobileOverride,
}) {
  final isMobile =
      isMobileOverride ?? (Platform.isAndroid || Platform.isIOS);
  if (!isMobile) return false;
  if (!baseUrl.startsWith('https://')) return false;
  if (pins.isEmpty) return false;
  if (pins.any((p) => p.startsWith('PASTE_'))) return false;
  return true;
}

void applyCertPinning(
  Dio dio, {
  required String baseUrl,
  required List<String> pins,
  bool? isMobileOverride,
}) {
  if (!shouldApplyCertPinning(
    baseUrl,
    pins: pins,
    isMobileOverride: isMobileOverride,
  )) {
    return;
  }

  // Match http_security_pinning example: mutate existing IO adapter.
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    return HttpSecurityPinningClient(pins);
  };
}
