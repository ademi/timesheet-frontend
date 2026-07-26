import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/contractor_shell.dart';
import '../shell/staff_shell.dart';
import 'bindings/compliance_ops_binding.dart';
import 'views/contractor_profile_ops_view.dart';
import 'views/staff_compliance_view.dart';

abstract final class ComplianceOpsPages {
  ComplianceOpsPages._();

  static List<GetPage> get routes => [
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
          binding: StaffComplianceBinding(),
          page: () => staffShellPage(const StaffComplianceView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorProfile,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: ContractorProfileOpsBinding(),
          page: () => contractorShellPage(const ContractorProfileOpsView()),
          transition: Transition.fadeIn,
        ),
      ];
}
