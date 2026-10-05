import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../rostering/presentation/composer/roster_composer_binding.dart';
import '../rostering/presentation/composer/roster_composer_view.dart';
import '../rostering/presentation/redirects/composer_cutover_middleware.dart';
import '../shell/contractor_shell.dart';
import '../shell/staff_shell.dart';
import '../shifts/views/staff_shift_detail_view.dart';
import '../shifts/group_book/group_shift_attendance_binding.dart';
import '../shifts/group_book/group_shift_attendance_view.dart';
import '../shifts/group_travel/group_shift_travel_binding.dart';
import '../shifts/group_travel/group_shift_travel_view.dart';
import 'bindings/visits_binding.dart';
import 'views/contractor_visit_detail_view.dart';
import 'views/contractor_visits_list_view.dart';
import 'views/staff_visit_detail_view.dart';
import 'views/staff_visits_board_view.dart';

abstract final class VisitsPages {
  VisitsPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffVisits,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.shiftsRead,
            AppPermissions.shiftsManage,
            AppPermissions.visitsRead,
            AppPermissions.visitsManage,
            AppPermissions.jobsManage,
          ],
        ),
      ],
      binding: StaffVisitsBinding(),
      page: () => staffShellPage(const StaffVisitsBoardView()),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.staffGroupShiftBook,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
        ComposerCutoverMiddleware(legacyRoute: AppRoutes.staffGroupShiftBook),
      ],
      binding: RosterComposerBinding(),
      page: () => const RosterComposerView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffShiftDetail,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.shiftsRead,
            AppPermissions.shiftsManage,
            AppPermissions.visitsRead,
            AppPermissions.visitsManage,
            AppPermissions.jobsManage,
          ],
        ),
      ],
      binding: StaffVisitsBinding(),
      page: () => const StaffShiftDetailView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffGroupShiftEdit,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
        ComposerCutoverMiddleware(legacyRoute: AppRoutes.staffGroupShiftEdit),
      ],
      binding: RosterComposerBinding(),
      page: () => const RosterComposerView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffGroupShiftWindows,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
        ComposerCutoverMiddleware(
          legacyRoute: AppRoutes.staffGroupShiftWindows,
        ),
      ],
      binding: RosterComposerBinding(),
      page: () => const RosterComposerView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffGroupShiftRemove,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
        ComposerCutoverMiddleware(legacyRoute: AppRoutes.staffGroupShiftRemove),
      ],
      binding: RosterComposerBinding(),
      page: () => const RosterComposerView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffGroupShiftAttendance,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
      ],
      binding: GroupShiftAttendanceBinding(),
      page: () => const GroupShiftAttendanceView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffGroupShiftPublish,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
        ComposerCutoverMiddleware(
          legacyRoute: AppRoutes.staffGroupShiftPublish,
        ),
      ],
      binding: RosterComposerBinding(),
      page: () => const RosterComposerView(),
      transition: Transition.rightToLeft,
    ),
    // Travel: no auto-redirect (deep-link / detail edit only).
    GetPage(
      name: AppRoutes.staffGroupShiftTravel,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.shiftsManage]),
      ],
      binding: GroupShiftTravelBinding(),
      page: () => const GroupShiftTravelView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffVisitDetail,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.visitsRead,
            AppPermissions.visitsManage,
            AppPermissions.jobsManage,
          ],
        ),
      ],
      binding: StaffVisitsBinding(),
      page: () => const StaffVisitDetailView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.contractorVisits,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: ContractorVisitsBinding(),
      page: () => contractorShellPage(const ContractorVisitsListView()),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.contractorVisitDetail,
      middlewares: [AuthGuard(), ActorGuard()],
      binding: ContractorVisitsBinding(),
      page: () => contractorShellPage(const ContractorVisitDetailView()),
      transition: Transition.rightToLeft,
    ),
  ];
}
