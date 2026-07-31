import 'package:flutter_test/flutter_test.dart';

import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/contractor_onboarding/onboarding_routing.dart';

void main() {
  group('OnboardingRouting.entryRoute', () {
    test('prioritizes platform compliance over engagement work', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: true,
          needsInviteAccept: true,
        ),
        AppRoutes.contractorOnboardingLegal,
      );
    });

    test('routes invited accept work to engagement', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: false,
          needsInviteAccept: true,
        ),
        AppRoutes.contractorOnboardingEngagement,
      );
    });

    test('does not force pending_docs work to credentials', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: false,
          needsInviteAccept: false,
        ),
        AppRoutes.contractorOnboarding,
      );
    });

    test('uses funnel entry fallback when neither axis needs work', () {
      expect(
        OnboardingRouting.entryRoute(
          needsPlatformCompliance: false,
          needsInviteAccept: false,
        ),
        AppRoutes.contractorOnboarding,
      );
    });
  });
}
