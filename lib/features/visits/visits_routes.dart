import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/contractor_shell.dart';
import '../shell/staff_shell.dart';
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
