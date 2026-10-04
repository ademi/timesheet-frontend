import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/billing/bindings/billing_binding.dart';
import '../../features/billing/views/invoice_export_detail_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

/// Full-screen billing GoRoutes (Phase 5.3).
///
/// Exports list tab stays under staff [ShellRoute] (supports `?tab=`).
/// Detail uses `?id=`.
List<RouteBase> buildBillingGoRoutes() => [
  GoRoute(
    path: AppRoutes.staffBillingExportDetail,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: const [
          AppPermissions.billingView,
          AppPermissions.billingManage,
        ],
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      StaffInvoiceExportDetailBinding().dependencies();
      return const InvoiceExportDetailView();
    },
  ),
];
