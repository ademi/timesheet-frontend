import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/contractor_me/bindings/complete_account_binding.dart';
import '../../features/contractor_me/views/complete_account_view.dart';
import '../../features/contractor_onboarding/bindings/onboarding_binding.dart';
import '../../features/contractor_onboarding/controllers/onboarding_controller.dart';
import '../../features/contractor_onboarding/views/onboarding_funnel_view.dart';
import '../routes/app_routes.dart';
import 'go_router_params.dart';

/// Contractor onboarding funnel + complete-account (Phase 5.4).
///
/// Outside contractor shell chrome (matches GetX). Each step path shows the
/// same funnel view; [OnboardingController] syncs via [AppNavigator.replace].
List<RouteBase> buildContractorOnboardingGoRoutes() => [
  _onboardingStep(AppRoutes.contractorOnboarding),
  _onboardingStep(AppRoutes.contractorOnboardingLegal),
  _onboardingStep(AppRoutes.contractorOnboardingNotices),
  _onboardingStep(AppRoutes.contractorOnboardingConsents),
  _onboardingStep(AppRoutes.contractorOnboardingEngagement),
  _onboardingStep(AppRoutes.contractorOnboardingCredentials),
  GoRoute(
    path: AppRoutes.contractorCompleteAccount,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      CompleteAccountBinding().dependencies();
      return const CompleteAccountView();
    },
  ),
];

GoRoute _onboardingStep(String path) {
  return GoRoute(
    path: path,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      OnboardingBinding().dependencies();
      // Cold start / deep link → first incomplete step (same as GetX pages).
      Future.microtask(() {
        OnboardingBinding.ensure();
        if (Get.isRegistered<OnboardingController>()) {
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        }
      });
      return const OnboardingFunnelView();
    },
  );
}
