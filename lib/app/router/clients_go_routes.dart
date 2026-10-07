import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/clients/bindings/client_onboarding_binding.dart';
import '../../features/clients/bindings/clients_binding.dart';
import '../../features/clients/bindings/strengths_needs_binding.dart';
import '../../features/clients/bindings/support_plan_binding.dart';
import '../../features/clients/views/client_contact_form_view.dart';
import '../../features/clients/views/client_detail_view.dart';
import '../../features/clients/views/client_form_view.dart';
import '../../features/clients/views/client_onboarding_view.dart';
import '../../features/clients/views/client_site_form_view.dart';
import '../../features/clients/views/public_client_invite_view.dart';
import '../../features/clients/views/strengths_needs_view.dart';
import '../../features/clients/views/support_plan_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

/// Full-screen client + public-invite GoRoutes (Phase 3).
///
/// Detail and wizard screens are **siblings** of the staff [ShellRoute] (not
/// nested under it) so they keep their own AppBar + back chrome without shell
/// nav — matching GetX `ClientsPages` behavior.
///
/// Query shape: prefer `?id=` / `?clientId=` / `?step=` (same as GetX params).
/// SIL list/detail stay under the staff shell (see [buildShellGoRoutes]).
List<RouteBase> buildClientsGoRoutes() => [
  _staffClientRoute(
    path: AppRoutes.staffClientDetail,
    anyOf: const [AppPermissions.clientsRead],
    onEnter: () => ClientsBinding().dependencies(),
    child: const ClientDetailView(),
  ),
  _staffClientRoute(
    path: AppRoutes.staffClientOnboarding,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => ClientOnboardingBinding().dependencies(),
    // Step URL sync uses replace on this same route — do not putFresh on enter.
    // Delete only when truly leaving so re-enter starts clean.
    onExit: () {
      // Query-only step URL replace can fire onExit then re-enter. [release]
      // is generation-gated and deferred so Identity TextFields stay valid.
      ClientOnboardingBinding.release();
      return true;
    },
    child: const ClientOnboardingView(),
  ),
  _staffClientRoute(
    path: AppRoutes.staffClientForm,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => ClientsBinding().dependencies(),
    child: const ClientFormView(),
  ),
  _staffClientRoute(
    path: AppRoutes.staffClientSupportPlan,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => SupportPlanBinding().dependencies(),
    child: const SupportPlanView(),
  ),
  _staffClientRoute(
    path: AppRoutes.staffClientStrengthsNeeds,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => StrengthsNeedsBinding().dependencies(),
    child: const StrengthsNeedsView(),
  ),
  _staffClientRoute(
    path: AppRoutes.staffClientSiteForm,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => ClientsBinding().dependencies(),
    child: const ClientSiteFormView(),
  ),
  _staffClientRoute(
    path: AppRoutes.staffClientContactForm,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => ClientsBinding().dependencies(),
    child: const ClientContactFormView(),
  ),
  GoRoute(
    path: AppRoutes.publicClientInvite,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      PublicClientInviteBinding().dependencies();
      return const PublicClientInviteView();
    },
  ),
  GoRoute(
    path: AppRoutes.publicClientInviteLegacy,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      PublicClientInviteBinding().dependencies();
      return const PublicClientInviteView();
    },
  ),
];

GoRoute _staffClientRoute({
  required String path,
  required List<String> anyOf,
  required VoidCallback onEnter,
  bool Function()? onExit,
  required Widget child,
}) {
  return GoRoute(
    path: path,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: anyOf,
      );
      return denied?.name;
    },
    onExit: onExit == null
        ? null
        : (context, state) {
            return onExit();
          },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      onEnter();
      return child;
    },
  );
}
