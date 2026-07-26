import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/clients_binding.dart';
import 'views/client_contact_form_view.dart';
import 'views/client_detail_view.dart';
import 'views/client_form_view.dart';
import 'views/client_site_form_view.dart';
import 'views/clients_list_view.dart';
import 'views/public_client_invite_view.dart';

abstract final class ClientsPages {
  ClientsPages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.staffClients,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsRead]),
          ],
          binding: ClientsBinding(),
          page: () => staffShellPage(const ClientsListView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffClientForm,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsManage]),
          ],
          binding: ClientsBinding(),
          page: () => const ClientFormView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffClientDetail,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsRead]),
          ],
          binding: ClientsBinding(),
          page: () => const ClientDetailView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffClientSiteForm,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsManage]),
          ],
          binding: ClientsBinding(),
          page: () => const ClientSiteFormView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffClientContactForm,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsManage]),
          ],
          binding: ClientsBinding(),
          page: () => const ClientContactFormView(),
          transition: Transition.rightToLeft,
        ),
        // Design path
        GetPage(
          name: AppRoutes.publicClientInvite,
          binding: PublicClientInviteBinding(),
          page: () => const PublicClientInviteView(),
          transition: Transition.fadeIn,
        ),
        // Backend email path alias (BH-005) — same screen
        GetPage(
          name: AppRoutes.publicClientInviteLegacy,
          binding: PublicClientInviteBinding(),
          page: () => const PublicClientInviteView(),
          transition: Transition.fadeIn,
        ),
      ];
}
