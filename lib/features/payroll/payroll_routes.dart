import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/contractor_shell.dart';
import '../shell/staff_shell.dart';
import 'bindings/payroll_binding.dart';
import 'views/contractor_payments_view.dart';
import 'views/staff_payments_view.dart';
import 'views/staff_tenant_settings_view.dart';

abstract final class PayrollPages {
  PayrollPages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.staffPayments,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(
              anyOf: [
                AppPermissions.paymentsView,
                AppPermissions.paymentsManage,
              ],
            ),
          ],
          binding: StaffPaymentsBinding(),
          page: () => staffShellPage(const StaffPaymentsView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffSettings,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(anyOf: [AppPermissions.authSession]),
          ],
          binding: StaffTenantSettingsBinding(),
          page: () => staffShellPage(const StaffTenantSettingsView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorPayments,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: ContractorPaymentsBinding(),
          page: () => contractorShellPage(const ContractorPaymentsView()),
          transition: Transition.fadeIn,
        ),
      ];
}
