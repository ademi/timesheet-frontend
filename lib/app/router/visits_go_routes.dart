import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shifts/group_book/group_shift_attendance_view.dart';
import '../../features/shifts/group_book/group_shift_book_binding.dart';
import '../../features/shifts/group_book/group_shift_book_view.dart';
import '../../features/shifts/group_book/group_shift_edit_binding.dart';
import '../../features/shifts/group_book/group_shift_edit_view.dart';
import '../../features/shifts/group_book/group_shift_remove_view.dart';
import '../../features/shifts/group_publish/group_shift_publish_binding.dart';
import '../../features/shifts/group_publish/group_shift_publish_view.dart';
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

/// Full-screen visit / shift / group-wizard GoRoutes (Phase 4).
///
/// Board + attendance stay under [ShellRoute] (see [buildShellGoRoutes]).
///
/// Group wizards under `/staff/visits/shift-detail/…` are **child routes** of
/// shift detail, pushed on [rootNavigatorKey] so they stay full-screen (no
/// nested navigator chrome). Query: `?id=` (+ `?participantId=` when needed).
/// [staffGroupShiftWindows] stays a local overlay (not a GoRoute).
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
    onEnter: () => GroupShiftBookBinding().dependencies(),
    child: const GroupShiftBookView(),
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
        onEnter: () => GroupShiftEditBinding().dependencies(),
        child: const GroupShiftEditView(),
      ),
      _shiftWizardChild(
        rootNavigatorKey: rootNavigatorKey,
        path: 'remove-participant',
        anyOf: _groupManageAnyOf,
        onEnter: () => GroupShiftRemoveBinding().dependencies(),
        child: const GroupShiftRemoveView(),
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
        onEnter: () => GroupShiftPublishBinding().dependencies(),
        child: const GroupShiftPublishView(),
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
