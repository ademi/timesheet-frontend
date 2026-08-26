import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/client_onboarding_binding.dart';
import 'bindings/clients_binding.dart';
import 'bindings/support_plan_binding.dart';
import 'views/client_contact_form_view.dart';
import 'views/client_detail_view.dart';
import 'views/client_form_view.dart';
import 'views/client_onboarding_view.dart';
import 'views/client_site_form_view.dart';
import 'views/clients_list_view.dart';
import 'views/public_client_invite_view.dart';
import 'views/support_plan_view.dart';

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
          name: AppRoutes.staffClientOnboarding,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsManage]),
          ],
          binding: ClientOnboardingBinding(),
          page: () => const ClientOnboardingView(),
          transition: Transition.rightToLeft,
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
          name: AppRoutes.staffClientSupportPlan,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsManage]),
          ],
          binding: SupportPlanBinding(),
          page: () => const SupportPlanView(),
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
        // Legacy alias for older emailed links — same screen
        GetPage(
          name: AppRoutes.publicClientInviteLegacy,
          binding: PublicClientInviteBinding(),
          page: () => const PublicClientInviteView(),
          transition: Transition.fadeIn,
        ),
      ];
}
