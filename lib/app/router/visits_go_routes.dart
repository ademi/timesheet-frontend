import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/rostering/presentation/composer/roster_composer_binding.dart';
import '../../features/rostering/presentation/composer/roster_composer_view.dart';
import '../../features/shifts/group_book/group_shift_attendance_binding.dart';
import '../../features/shifts/group_book/group_shift_attendance_view.dart';
import '../../features/shifts/group_travel/group_shift_travel_binding.dart';
import '../../features/shifts/group_travel/group_shift_travel_view.dart';
import '../../features/shifts/views/staff_shift_detail_view.dart';
import '../../features/visits/bindings/visits_binding.dart';
import '../../features/visits/views/staff_visit_detail_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

const _shiftReadAnyOf = [
  AppPermissions.shiftsRead,
  AppPermissions.shiftsManage,
  AppPermissions.visitsRead,
  AppPermissions.visitsManage,
  AppPermissions.jobsManage,
];

const _groupManageAnyOf = [
  AppPermissions.shiftsManage,
  AppPermissions.jobsManage,
];

/// Full-screen visit / shift GoRoutes.
///
/// Legacy group book/edit/publish paths open the Roster Composer.
/// Participant attendance (ios) is kept as its own screen.
List<RouteBase> buildVisitsGoRoutes({
  required GlobalKey<NavigatorState> rootNavigatorKey,
}) => [
  _staffRoute(
    path: AppRoutes.staffVisitDetail,
    anyOf: const [
      AppPermissions.visitsRead,
      AppPermissions.visitsManage,
      AppPermissions.jobsManage,
    ],
    onEnter: () => StaffVisitsBinding().dependencies(),
    child: const StaffVisitDetailView(),
  ),
  _staffRoute(
    path: AppRoutes.staffGroupShiftBook,
    anyOf: _groupManageAnyOf,
    onEnter: () => RosterComposerBinding().dependencies(),
    child: const RosterComposerView(),
  ),
  GoRoute(
    path: AppRoutes.staffShiftDetail,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: _shiftReadAnyOf,
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      StaffVisitsBinding().dependencies();
      return const StaffShiftDetailView();
    },
    routes: [
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'edit-group',
        anyOf: _groupManageAnyOf,
        onEnter: () => RosterComposerBinding().dependencies(),
        child: const RosterComposerView(),
      ),
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'remove-participant',
        anyOf: _groupManageAnyOf,
        onEnter: () => RosterComposerBinding().dependencies(),
        child: const RosterComposerView(),
      ),
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'participant-windows',
        anyOf: _groupManageAnyOf,
        onEnter: () => RosterComposerBinding().dependencies(),
        child: const RosterComposerView(),
      ),
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'participant-attendance',
        anyOf: _groupManageAnyOf,
        onEnter: () => GroupShiftAttendanceBinding().dependencies(),
        child: const GroupShiftAttendanceView(),
      ),
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'publish-group',
        anyOf: _groupManageAnyOf,
        onEnter: () => RosterComposerBinding().dependencies(),
        child: const RosterComposerView(),
      ),
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'travel',
        anyOf: const [AppPermissions.shiftsManage],
        onEnter: () => GroupShiftTravelBinding().dependencies(),
        child: const GroupShiftTravelView(),
      ),
    ],
  ),
];

GoRoute _shiftWizardChild({
  required GlobalKey<NavigatorState> rootNavigatorKey,
  required String path,
  required List<String> anyOf,
  required VoidCallback onEnter,
  required Widget child,
}) {
  return GoRoute(
    path: path,
    parentNavigatorKey: rootNavigatorKey,
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
