import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../../app/constants/app_permissions.dart';
import '../../app/views/v2/wrong_actor_view.dart';
import '../clients/clients_routes.dart';
import '../contractor_onboarding/contractor_onboarding_routes.dart';
import '../contractor_register/contractor_register_routes.dart';
import '../contractor_schedule/contractor_schedule_routes.dart';
import '../credentials/credentials_routes.dart';
import '../engagements/engagements_routes.dart';
import '../jobs/jobs_routes.dart';
import '../visits/visits_routes.dart';
import 'contractor_shell.dart';
import 'staff_shell.dart';

/// Dual-shell GetPages for Staff + Contractor (S0 stubs).
abstract final class ShellPages {
  ShellPages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.wrongActor,
          page: () => const WrongActorView(),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffHome,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.authSession]),
          ],
          page: staffHomeStub,
          transition: Transition.fadeIn,
        ),
        // staffWorkforce + staffClients + staffJobs + staffVisits via feature modules
        GetPage(
          name: AppRoutes.staffPayments,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.paymentsView]),
          ],
          page: staffPaymentsStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffCompliance,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(
              anyOf: [
                AppPermissions.credentialsReview,
                AppPermissions.complianceRightsManage,
                AppPermissions.complianceIncidentsManage,
                AppPermissions.complianceAuditView,
              ],
            ),
          ],
          page: staffComplianceStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffSettings,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.authSession]),
          ],
          page: staffSettingsStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorHome,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorHomeStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorProfile,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorProfileStub,
          transition: Transition.fadeIn,
        ),
        ...EngagementsPages.routes,
        ...ClientsPages.routes,
        ...JobsPages.routes,
        ...VisitsPages.routes,
        ...ContractorSchedulePages.routes,
        ...CredentialsPages.routes,
        ...ContractorOnboardingPages.routes,
        ContractorRegisterPages.page,
      ];
}
