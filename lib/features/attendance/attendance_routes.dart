import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/attendance_binding.dart';
import 'views/attendance_review_view.dart';

abstract final class AttendancePages {
  AttendancePages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffAttendanceReview,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.attendanceAdjust,
            AppPermissions.visitsManage,
          ],
        ),
      ],
      binding: AttendanceReviewBinding(),
      page: () => staffShellPage(const AttendanceReviewView()),
      transition: Transition.fadeIn,
    ),
  ];
}
