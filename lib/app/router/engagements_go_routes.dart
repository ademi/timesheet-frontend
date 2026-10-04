import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/engagements/bindings/engagements_binding.dart';
import '../../features/engagements/views/workforce_detail_view.dart';
import '../../features/engagements/views/workforce_invite_view.dart';
import '../../features/payroll/views/engagement_rate_form_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

/// Full-screen workforce GoRoutes (Phase 5.1).
///
/// List tab stays under staff [ShellRoute]. Rate-form is a child of detail
/// (`/staff/workforce/detail/rate-form`) pushed on [rootNavigatorKey].
List<RouteBase> buildEngagementsGoRoutes({
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) => [
  _staffRoute(
    path: AppRoutes.staffWorkforceInvite,
    anyOf: const [AppPermissions.contractorsInvite],
    onEnter: () => EngagementsBinding().dependencies(),
    child: const WorkforceInviteView(),
  ),
  GoRoute(
    path: AppRoutes.staffWorkforceDetail,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: const [AppPermissions.contractorsRead],
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      EngagementsBinding().dependencies();
      return const WorkforceDetailView();
    },
    routes: [
      GoRoute(
        path: 'rate-form',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final denied = redirectMissingPermission(
            route: state.matchedLocation,
            anyOf: const [AppPermissions.paymentsManage],
          );
          return denied?.name;
        },
        builder: (context, state) {
          syncGetxFromGoRouterState(state);
          EngagementsBinding().dependencies();
          return const EngagementRateFormView();
        },
      ),
    ],
  ),
];

GoRoute _staffRoute({
  required String path,
  required List<String> anyOf,
  required VoidCallback onEnter,
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
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      onEnter();
      return child;
    },
  );
}
