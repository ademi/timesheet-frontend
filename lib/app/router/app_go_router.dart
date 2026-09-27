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
import 'billing_go_routes.dart';
import 'clients_go_routes.dart';
import 'contractor_onboarding_go_routes.dart';
import 'credentials_go_routes.dart';
import 'engagements_go_routes.dart';
import 'go_router_redirect.dart';
import 'jobs_go_routes.dart';
import 'shell_go_routes.dart';
import 'visits_go_routes.dart';

/// Builds the web [GoRouter] (Phase 1–5: auth, shells, domain deep links).
///
/// [AppNavigator.bindWebRouter] is called here so auth / shell call sites can
/// navigate without importing go_router directly.
GoRouter createAppGoRouter({String? initialLocation}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'appRoot');
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
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
      ...buildClientsGoRoutes(),
      ...buildVisitsGoRoutes(rootNavigatorKey: rootNavigatorKey),
      ...buildJobsGoRoutes(),
      ...buildEngagementsGoRoutes(rootNavigatorKey: rootNavigatorKey),
      ...buildCredentialsGoRoutes(),
      ...buildBillingGoRoutes(),
      ...buildContractorOnboardingGoRoutes(),
    ],
    errorBuilder: (context, state) => UnknownRoutePage(uri: state.uri),
  );
  AppNavigator.bindWebRouter(router);
  return router;
}

/// Safe fallback for unmatched / mistyped URLs on web.
///
/// Logs once per build, then offers [AppNavigator.offAll] to gateway (logged out)
/// or the post-login home (authenticated). Intentional exception:
/// [AppRoutes.staffGroupShiftWindows] is a local overlay, not a GoRoute.
class UnknownRoutePage extends StatefulWidget {
  const UnknownRoutePage({super.key, required this.uri});

  final Uri uri;

  @override
  State<UnknownRoutePage> createState() => _UnknownRoutePageState();
}

class _UnknownRoutePageState extends State<UnknownRoutePage> {
  @override
  void initState() {
    super.initState();
    final authed = redirectWhenUnauthenticated() == null;
    debugPrint(
      '[go_router] unknown route path=${widget.uri.path} '
      'query=${widget.uri.query} authenticated=$authed',
    );
  }

  String get _safeHome {
    final home =
        Get.isRegistered<SessionService>()
            ? Get.find<SessionService>().resolvePostLoginRoute()
            : AppRoutes.gateway;
    if (home == AppRoutes.login || home == AppRoutes.gateway) {
      return AppRoutes.gateway;
    }
    return home;
  }

  void _goHome() {
    if (redirectWhenUnauthenticated() != null) {
      AppNavigator.offAll(AppRoutes.gateway);
    } else {
      AppNavigator.offAll(_safeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Page not found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.uri.path,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _goHome,
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deprecated alias kept for any lingering references.
@Deprecated('Use UnknownRoutePage')
class Phase1UnknownRoutePage extends UnknownRoutePage {
  const Phase1UnknownRoutePage({super.key, required super.uri});
}
