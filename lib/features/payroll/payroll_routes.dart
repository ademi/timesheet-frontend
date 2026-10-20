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
import 'views/staff_add_view.dart';
import 'views/staff_detail_view.dart';
import 'views/staff_list_view.dart';
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
          anyOf: [AppPermissions.paymentsView, AppPermissions.paymentsManage],
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
      name: AppRoutes.staffMembers,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [
            AppPermissions.tenantMembersRead,
            AppPermissions.tenantMembersManage,
          ],
        ),
      ],
      binding: StaffListBinding(),
      page: () => staffShellPage(const StaffListView()),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.staffAdd,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.tenantMembersManage]),
      ],
      binding: StaffAddBinding(),
      page: () => const StaffAddView(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.staffDetail,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(anyOf: [AppPermissions.tenantMembersManage]),
      ],
      binding: StaffDetailBinding(),
      page: () => const StaffDetailView(),
      transition: Transition.rightToLeft,
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
