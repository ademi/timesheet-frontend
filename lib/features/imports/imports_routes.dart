import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import 'bindings/imports_binding.dart';
import 'data/models/import_models.dart';
import 'views/csv_import_view.dart';

abstract final class ImportsPages {
  ImportsPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffClientsImport,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.clientsManage]),
      ],
      binding: ImportsBinding(kind: ImportKind.participants),
      page: () => const CsvImportView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffWorkforceImport,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.contractorsInvite]),
      ],
      binding: ImportsBinding(kind: ImportKind.workers),
      page: () => const CsvImportView(),
      transition: Transition.rightToLeft,
    ),
  ];
}
