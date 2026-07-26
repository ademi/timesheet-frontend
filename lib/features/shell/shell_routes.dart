import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../../app/constants/app_permissions.dart';
import '../../app/views/v2/wrong_actor_view.dart';
import '../contractor_onboarding/contractor_onboarding_routes.dart';
import '../contractor_register/contractor_register_routes.dart';
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
        GetPage(
          name: AppRoutes.staffWorkforce,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.contractorsRead]),
          ],
          page: staffWorkforceStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffClients,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.clientsRead]),
          ],
          page: staffClientsStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffJobs,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.jobsRead]),
          ],
          page: staffJobsStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffVisits,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.visitsRead]),
          ],
          page: staffVisitsStub,
          transition: Transition.fadeIn,
        ),
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
          name: AppRoutes.contractorVisits,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorVisitsStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorVisitDetail,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorVisitDetailStub,
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.contractorSchedule,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorScheduleStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorCredentials,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorCredentialsStub,
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorProfile,
          middlewares: [AuthGuard(), ActorGuard()],
          page: contractorProfileStub,
          transition: Transition.fadeIn,
        ),
        ...ContractorOnboardingPages.routes,
        ContractorRegisterPages.page,
      ];
}
