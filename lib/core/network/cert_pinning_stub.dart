import 'package:dio/dio.dart';

bool shouldApplyCertPinning(
  String baseUrl, {
  List<String> pins = const [],
  bool? isMobileOverride,
}) {
  // Web: browser TLS only — never claim pinning is active.
  return false;
}

void applyCertPinning(
  Dio dio, {
  required String baseUrl,
  required List<String> pins,
  bool? isMobileOverride,
}) {
  // no-op on web
}
