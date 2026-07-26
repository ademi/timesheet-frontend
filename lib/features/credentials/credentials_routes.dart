import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../../app/routes/middlewares/permission_guard.dart';
import '../../app/constants/app_permissions.dart';
import '../shell/contractor_shell.dart';
import 'bindings/credentials_binding.dart';
import 'views/credential_create_view.dart';
import 'views/credential_detail_view.dart';
import 'views/credentials_list_view.dart';
import 'views/staff_credential_review_view.dart';

abstract final class CredentialsPages {
  CredentialsPages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.contractorCredentials,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: CredentialsBinding(),
          page: () => contractorShellPage(const CredentialsListView()),
          transition: Transition.fadeIn,
        ),
        GetPage(
          name: AppRoutes.contractorCredentialCreate,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: CredentialsBinding(),
          page: () => const CredentialCreateView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.contractorCredentialDetail,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: CredentialsBinding(),
          page: () => const CredentialDetailView(),
          transition: Transition.rightToLeft,
        ),
        GetPage(
          name: AppRoutes.staffCredentialReview,
          middlewares: [
            AuthGuard(),
            ActorGuard(),
            PermissionGuard(
              anyOf: [
                AppPermissions.credentialsRead,
                AppPermissions.credentialsReview,
              ],
            ),
          ],
          binding: StaffCredentialReviewBinding(),
          page: () => const StaffCredentialReviewView(),
          transition: Transition.fadeIn,
        ),
      ];
}
