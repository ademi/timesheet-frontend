import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guard: logout must drop permanent shell/funnel controllers.
///
/// Runtime wiring is in [AuthController.logout] →
/// `OnboardingBinding.reset()` + `HomeAlertsBinding.reset()`.
void main() {
  test('AuthController.logout calls onboarding + home-alerts reset', () {
    final source = File(
      'lib/app/controllers/auth_controller.dart',
    ).readAsStringSync();
    expect(source.contains('OnboardingBinding.reset()'), isTrue);
    expect(source.contains('HomeAlertsBinding.reset()'), isTrue);
  });

  test('HomeAlertsBinding and OnboardingBinding expose reset()', () {
    expect(
      File(
        'lib/features/compliance_ops/bindings/compliance_ops_binding.dart',
      ).readAsStringSync().contains('static void reset()'),
      isTrue,
    );
    expect(
      File(
        'lib/features/contractor_onboarding/bindings/onboarding_binding.dart',
      ).readAsStringSync().contains('static void reset()'),
      isTrue,
    );
  });
}
