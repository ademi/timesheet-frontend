import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import 'presentation/composer/roster_composer_binding.dart';
import 'presentation/composer/roster_composer_view.dart';

abstract final class RosteringPages {
  RosteringPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffRosterCompose,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.shiftsManage, AppPermissions.jobsManage],
        ),
      ],
      binding: RosterComposerBinding(),
      page: () => const RosterComposerView(),
      transition: Transition.rightToLeft,
    ),
  ];
}
