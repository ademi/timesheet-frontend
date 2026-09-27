import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/session_service.dart';
import '../../features/contractor_register/bindings/contractor_register_binding.dart';
import '../../features/contractor_register/views/contractor_register_view.dart';
import '../bindings/auth_binding.dart';
import '../bindings/branch_gateway_binding.dart';
import '../bindings/first_login_binding.dart';
import '../bindings/gateway_binding.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import '../themes/app_colors.dart';
import '../views/branch_gateway_view.dart';
import '../views/first_login_view.dart';
import '../views/gateway_view.dart';
import '../views/login_view.dart';
import '../views/v2/wrong_actor_view.dart';
import 'go_router_redirect.dart';
import 'shell_go_routes.dart';

/// Builds the web [GoRouter] (Phase 1 auth entry + Phase 2 shell tabs).
///
/// [AppNavigator.bindWebRouter] is called here so auth / shell call sites can
/// navigate without importing go_router directly.
GoRouter createAppGoRouter({String? initialLocation}) {
  final router = GoRouter(
    initialLocation: initialLocation ?? AppRoutes.gateway,
    debugLogDiagnostics: kDebugMode,
    redirect: appGoRouterRedirect,
    routes: [
      GoRoute(
        path: AppRoutes.gateway,
        builder: (context, state) {
          GatewayBinding().dependencies();
          return const GatewayView();
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          AuthBinding().dependencies();
          return const LoginView();
        },
      ),
      GoRoute(
        path: AppRoutes.firstLogin,
        builder: (context, state) {
          FirstLoginBinding().dependencies();
          return const FirstLoginView();
        },
      ),
      GoRoute(
        path: AppRoutes.adminBranchGateway,
        builder: (context, state) {
          BranchGatewayBinding().dependencies();
          return const BranchGatewayView();
        },
      ),
      GoRoute(
        path: AppRoutes.wrongActor,
        builder: (context, state) => const WrongActorView(),
      ),
      // Auth-entry public register (gateway / login link here).
      GoRoute(
        path: AppRoutes.contractorRegister,
        builder: (context, state) {
          ContractorRegisterBinding().dependencies();
          return const ContractorRegisterView();
        },
      ),
      GoRoute(
        path: AppRoutes.contractorRegisterWithToken,
        builder: (context, state) {
          ContractorRegisterBinding().dependencies();
          return const ContractorRegisterView();
        },
      ),
      ...buildShellGoRoutes(),
    ],
    errorBuilder: (context, state) => Phase1UnknownRoutePage(uri: state.uri),
  );
  AppNavigator.bindWebRouter(router);
  return router;
}

/// Shown for bookmarks to routes not yet migrated to go_router (Phase 3+).
class Phase1UnknownRoutePage extends StatelessWidget {
  const Phase1UnknownRoutePage({super.key, required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final home =
        Get.isRegistered<SessionService>()
            ? Get.find<SessionService>().resolvePostLoginRoute()
            : AppRoutes.gateway;
    final safeHome =
        home == AppRoutes.login || home == AppRoutes.gateway
            ? AppRoutes.gateway
            : home;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'This page isn’t on web yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                uri.path,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (redirectWhenUnauthenticated() != null) {
                    AppNavigator.offAll(AppRoutes.gateway);
                  } else {
                    AppNavigator.offAll(safeHome);
                  }
                },
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
