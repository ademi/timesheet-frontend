import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/routes/middlewares/actor_guard.dart';
import '../../../app/routes/middlewares/auth_guard.dart';
import '../../../app/routes/middlewares/permission_guard.dart';
import '../shell/staff_shell.dart';
import 'bindings/billing_binding.dart';
import 'views/invoice_export_detail_view.dart';
import 'views/invoice_exports_list_view.dart';

abstract final class BillingPages {
  BillingPages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.staffBillingExports,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(
              anyOf: [
                AppPermissions.billingView,
                AppPermissions.billingManage,
              ],
            ),
          ],
          binding: StaffInvoiceExportsBinding(),
          page: () => staffShellPage(const InvoiceExportsListView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.staffBillingExportDetail,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(
              anyOf: [
                AppPermissions.billingView,
                AppPermissions.billingManage,
              ],
            ),
          ],
          binding: StaffInvoiceExportDetailBinding(),
          page: () => const InvoiceExportDetailView(),
          transition: Transition.rightToLeft,
        ),
      ];
}
