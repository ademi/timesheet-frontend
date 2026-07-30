import '../../app/routes/app_routes.dart';
import 'controllers/onboarding_controller.dart';

abstract final class OnboardingRouting {
  static String entryRoute({
    required bool needsPlatformCompliance,
    required bool needsEngagementWork,
  }) {
    if (needsPlatformCompliance) return AppRoutes.contractorOnboardingLegal;
    if (needsEngagementWork) return AppRoutes.contractorOnboardingEngagement;
    return AppRoutes.contractorOnboarding;
  }

  static String routeForStep(OnboardingStep step) {
    return switch (step) {
      OnboardingStep.legal => AppRoutes.contractorOnboardingLegal,
      OnboardingStep.notices => AppRoutes.contractorOnboardingNotices,
      OnboardingStep.consents => AppRoutes.contractorOnboardingConsents,
      OnboardingStep.engagement => AppRoutes.contractorOnboardingEngagement,
      OnboardingStep.credentials => AppRoutes.contractorOnboardingCredentials,
    };
  }
}
