import 'package:go_router/go_router.dart';

import '../../features/payroll/bindings/payroll_binding.dart';
import '../../features/payroll/views/staff_add_view.dart';
import '../../features/payroll/views/staff_detail_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

/// Full-screen staff management GoRoutes (Add Staff, detail, etc.).
List<RouteBase> buildStaffGoRoutes() => [
  GoRoute(
    path: AppRoutes.staffAdd,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: const [AppPermissions.tenantMembersManage],
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      StaffAddBinding().dependencies();
      return const StaffAddView();
    },
  ),
  GoRoute(
    path: AppRoutes.staffDetail,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: const [AppPermissions.tenantMembersManage],
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      StaffDetailBinding().dependencies();
      return const StaffDetailView();
    },
  ),
];
