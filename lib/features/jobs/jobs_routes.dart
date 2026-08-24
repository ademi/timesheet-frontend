import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/jobs_binding.dart';
import 'views/form_template_editor_view.dart';
import 'views/form_templates_view.dart';
import 'views/job_detail_view.dart';
import 'views/job_form_view.dart';
import 'views/job_manage_templates_view.dart';
import 'views/jobs_list_view.dart';
import 'views/recurrence_rule_form_view.dart';
import 'views/unified_support_view.dart';

abstract final class JobsPages {
  JobsPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffJobs,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.jobsRead]),
      ],
      binding: JobsBinding(),
      page: () => staffShellPage(const JobsListView()),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.staffJobForm,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.jobsManage]),
      ],
      binding: JobsBinding(),
      page: () => const JobFormView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffOngoingSupport,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.jobsManage]),
      ],
      binding: UnifiedSupportBinding(),
      page: () => const UnifiedSupportView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffUnifiedSupport,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.jobsManage]),
      ],
      binding: UnifiedSupportBinding(),
      page: () => const UnifiedSupportView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffJobDetail,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.jobsRead]),
      ],
      binding: JobsBinding(),
      page: () => const JobDetailView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffRecurrenceRuleForm,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.jobsManage]),
      ],
      binding: JobsBinding(),
      page: () => const RecurrenceRuleFormView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffFormTemplates,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.jobsRead,
            AppPermissions.clientsRead,
            AppPermissions.clientsManage,
          ],
        ),
      ],
      binding: JobsBinding(),
      page: () => const FormTemplatesView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffJobManageTemplates,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.jobsRead,
            AppPermissions.clientsRead,
            AppPermissions.clientsManage,
          ],
        ),
      ],
      binding: JobsBinding(),
      page: () => const JobManageTemplatesView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffFormTemplateEditor,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.clientsManage]),
      ],
      binding: JobsBinding(),
      page: () => const FormTemplateEditorView(),
      transition: Transition.rightToLeft,
    ),
  ];
}
