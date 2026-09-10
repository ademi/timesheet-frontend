import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/billing_binding.dart';
import 'views/staff_invoice_detail_view.dart';
import 'views/staff_invoices_view.dart';

abstract final class BillingPages {
  BillingPages._();

  static List<GetPage> get routes => [
    GetPage(
      name: AppRoutes.staffInvoices,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.billingView, AppPermissions.billingManage],
        ),
      ],
      binding: StaffInvoicesBinding(),
      page: () => staffShellPage(const StaffInvoicesView()),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppRoutes.staffInvoiceDetail,
      middlewares: [
        AuthGuard(),
        ActorGuard(),
        PermissionGuard(
          anyOf: [AppPermissions.billingView, AppPermissions.billingManage],
        ),
      ],
      binding: StaffInvoicesBinding(),
      page: () => staffShellPage(const StaffInvoiceDetailView()),
      transition: Transition.rightToLeft,
    ),
  ];
}
