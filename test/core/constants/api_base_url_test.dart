import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/constants/app_constants.dart';
import 'package:rostiq/core/constants/feature_flags.dart';

void main() {
  test('AppEnv.apiBaseUrl matches AppConstants.baseUrl', () {
    expect(AppEnv.apiBaseUrl, AppConstants.baseUrl);
  });
}
