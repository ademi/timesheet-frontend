import 'package:go_router/go_router.dart';

import '../../features/credentials/bindings/credentials_binding.dart';
import '../../features/credentials/views/credential_create_view.dart';
import '../../features/credentials/views/credential_detail_view.dart';
import '../../features/credentials/views/credential_missing_create_view.dart';
import '../../features/credentials/views/staff_credential_review_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';

/// Full-screen credentials GoRoutes (Phase 5.2).
///
/// Contractor credentials list stays under contractor [ShellRoute].
/// Query: credential detail `?id=`; staff review `?contractorId=&engagementId=`;
/// missing create `?types=a,b`.
List<RouteBase> buildCredentialsGoRoutes() => [
  GoRoute(
    path: AppRoutes.contractorCredentialCreate,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      CredentialsBinding().dependencies();
      return const CredentialCreateView();
    },
  ),
  GoRoute(
    path: AppRoutes.contractorCredentialCreateMissing,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      CredentialsBinding().dependencies();
      return const CredentialMissingCreateView();
    },
  ),
  GoRoute(
    path: AppRoutes.contractorCredentialDetail,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      CredentialsBinding().dependencies();
      return const CredentialDetailView();
    },
  ),
  GoRoute(
    path: AppRoutes.staffCredentialReview,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: const [
          AppPermissions.credentialsRead,
          AppPermissions.credentialsReview,
        ],
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      StaffCredentialReviewBinding().dependencies();
      return const StaffCredentialReviewView();
    },
  ),
];
