import 'package:flutter_test/flutter_test.dart';

import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/contractor_onboarding/onboarding_routing.dart';

void main() {
  group('OnboardingRouting.entryRoute', () {
    test('prioritizes platform compliance over engagement work', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: true,
          needsEngagementWork: true,
        ),
        AppRoutes.contractorOnboardingLegal,
      );
    });

    test('routes platform-complete engagement work to engagement', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: false,
          needsEngagementWork: true,
        ),
        AppRoutes.contractorOnboardingEngagement,
      );
    });

    test('uses funnel entry fallback when neither axis needs work', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: false,
          needsEngagementWork: false,
        ),
        AppRoutes.contractorOnboarding,
      );
    });
  });
}
