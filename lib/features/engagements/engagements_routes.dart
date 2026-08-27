import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/contractor_onboarding_binding.dart';
import 'bindings/engagements_binding.dart';
import 'views/contractor_onboarding_view.dart';
import 'views/workforce_detail_view.dart';
import 'views/workforce_invite_view.dart';
import 'views/workforce_list_view.dart';
import '../payroll/views/engagement_rate_form_view.dart';

abstract final class EngagementsPages {
  EngagementsPages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.staffWorkforce,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.contractorsRead]),
          ],
          binding: EngagementsBinding(),
          page: () => staffShellPage(const WorkforceListView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffWorkforceInvite,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.contractorsInvite]),
          ],
          binding: EngagementsBinding(),
          page: () => const WorkforceInviteView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffWorkforceOnboarding,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.contractorsInvite]),
          ],
          binding: ContractorOnboardingBinding(),
          page: () => const ContractorOnboardingView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffWorkforceDetail,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.contractorsRead]),
          ],
          binding: EngagementsBinding(),
          page: () => const WorkforceDetailView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffWorkforceRateForm,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(
              anyOf: [AppPermissions.paymentsManage],
            ),
          ],
          binding: EngagementsBinding(),
          page: () => const EngagementRateFormView(),
          transition: Transition.rightToLeft,
        ),
      ];
}
