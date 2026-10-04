import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/jobs/bindings/jobs_binding.dart';
import '../../features/jobs/views/form_template_editor_view.dart';
import '../../features/jobs/views/form_templates_view.dart';
import '../../features/jobs/views/job_detail_view.dart';
import '../../features/jobs/views/job_form_view.dart';
import '../../features/jobs/views/job_manage_templates_view.dart';
import '../../features/jobs/views/recurrence_rule_form_view.dart';
import '../../features/jobs/views/unified_support_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

/// Full-screen jobs / templates / unified-support GoRoutes (Phase 4).
///
/// Jobs list lives under the staff [ShellRoute] (see [buildShellGoRoutes]).
/// Query shape: `?id=` for job detail / manage-templates; unified support uses
/// `?clientId=` / `?mode=` / `?step=` when present.
List<RouteBase> buildJobsGoRoutes() => [
  _staffRoute(
    path: AppRoutes.staffJobDetail,
    anyOf: const [AppPermissions.jobsRead],
    onEnter: () => JobsBinding().dependencies(),
    child: const JobDetailView(),
  ),
  _staffRoute(
    path: AppRoutes.staffJobForm,
    anyOf: const [AppPermissions.jobsManage],
    onEnter: () => JobsBinding().dependencies(),
    child: const JobFormView(),
  ),
  _staffRoute(
    path: AppRoutes.staffUnifiedSupport,
    anyOf: const [AppPermissions.jobsManage],
    onEnter: () => UnifiedSupportBinding().dependencies(),
    child: const UnifiedSupportView(),
  ),
  _staffRoute(
    path: AppRoutes.staffOngoingSupport,
    anyOf: const [AppPermissions.jobsManage],
    onEnter: () => UnifiedSupportBinding().dependencies(),
    child: const UnifiedSupportView(),
  ),
  _staffRoute(
    path: AppRoutes.staffRecurrenceRuleForm,
    anyOf: const [AppPermissions.jobsManage],
    onEnter: () => JobsBinding().dependencies(),
    child: const RecurrenceRuleFormView(),
  ),
  _staffRoute(
    path: AppRoutes.staffFormTemplates,
    anyOf: const [
      AppPermissions.jobsRead,
      AppPermissions.clientsRead,
      AppPermissions.clientsManage,
    ],
    onEnter: () => JobsBinding().dependencies(),
    child: const FormTemplatesView(),
  ),
  _staffRoute(
    path: AppRoutes.staffJobManageTemplates,
    anyOf: const [
      AppPermissions.jobsRead,
      AppPermissions.clientsRead,
      AppPermissions.clientsManage,
    ],
    onEnter: () => JobsBinding().dependencies(),
    child: const JobManageTemplatesView(),
  ),
  _staffRoute(
    path: AppRoutes.staffFormTemplateEditor,
    anyOf: const [AppPermissions.clientsManage],
    onEnter: () => JobsBinding().dependencies(),
    child: const FormTemplateEditorView(),
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
