import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import 'bindings/onboarding_binding.dart';
import 'controllers/onboarding_controller.dart';
import 'views/onboarding_funnel_view.dart';

/// Onboarding GetPages — outside ContractorShell tab chrome.
abstract final class ContractorOnboardingPages {
  ContractorOnboardingPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.contractorOnboarding,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: OnboardingBinding(),
      page: () {
        // Entry → first incomplete step.
        Future.microtask(() {
          OnboardingBinding.ensure();
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        });
        return const OnboardingFunnelView();
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contractorOnboardingLegal,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: OnboardingBinding(),
      page: () {
        // Cold start via entryRoute often lands here — skip if already accepted.
        Future.microtask(() {
          OnboardingBinding.ensure();
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        });
        return const OnboardingFunnelView();
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contractorOnboardingNotices,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: OnboardingBinding(),
      page: () {
        Future.microtask(() {
          OnboardingBinding.ensure();
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        });
        return const OnboardingFunnelView();
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contractorOnboardingConsents,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: OnboardingBinding(),
      page: () {
        Future.microtask(() {
          OnboardingBinding.ensure();
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        });
        return const OnboardingFunnelView();
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contractorOnboardingEngagement,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: OnboardingBinding(),
      page: () {
        Future.microtask(() {
          OnboardingBinding.ensure();
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        });
        return const OnboardingFunnelView();
      },
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contractorOnboardingCredentials,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: OnboardingBinding(),
      page: () {
        Future.microtask(() {
          OnboardingBinding.ensure();
          Get.find<OnboardingController>().navigateToFirstIncompleteStep();
        });
        return const OnboardingFunnelView();
      },
      transition: Transition.fadeIn,
    ),
  ];
}
