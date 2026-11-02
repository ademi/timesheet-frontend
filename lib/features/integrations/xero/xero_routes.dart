import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/routes/middlewares/actor_guard.dart';
import '../../../app/routes/middlewares/auth_guard.dart';
import '../../../app/routes/middlewares/permission_guard.dart';
import 'bindings/xero_binding.dart';
import 'views/xero_settings_view.dart';

abstract final class XeroPages {
  XeroPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffXeroSettings,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.integrationsXeroManage]),
      ],
      binding: XeroSettingsBinding(),
      page: () => const XeroSettingsView(),
      transition: Transition.rightToLeft,
    ),
    // BE OAuth success/error default lands on this path.
    GetPage(
      name: AppRoutes.xeroSettingsOAuthReturn,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.integrationsXeroManage]),
      ],
      binding: XeroSettingsBinding(),
      page: () => const XeroSettingsView(),
      transition: Transition.fadeIn,
    ),
  ];
}
