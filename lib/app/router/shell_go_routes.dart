import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/bindings/attendance_binding.dart';
import '../../features/attendance/views/attendance_review_view.dart';
import '../../features/billing/bindings/billing_binding.dart';
import '../../features/billing/views/invoice_exports_list_view.dart';
import '../../features/clients/bindings/clients_binding.dart';
import '../../features/clients/views/clients_list_view.dart';
import '../../features/compliance_ops/bindings/compliance_ops_binding.dart';
import '../../features/compliance_ops/views/contractor_profile_ops_view.dart';
import '../../features/compliance_ops/views/home_alerts_view.dart';
import '../../features/compliance_ops/views/staff_compliance_view.dart';
import '../../features/contractor_schedule/bindings/contractor_schedule_binding.dart';
import '../../features/contractor_schedule/views/contractor_schedule_view.dart';
import '../../features/credentials/bindings/credentials_binding.dart';
import '../../features/credentials/views/credentials_list_view.dart';
import '../../features/engagements/bindings/engagements_binding.dart';
import '../../features/engagements/views/workforce_list_view.dart';
import '../../features/jobs/bindings/jobs_binding.dart';
import '../../features/jobs/views/jobs_list_view.dart';
import '../../features/payroll/bindings/payroll_binding.dart';
import '../../features/payroll/views/staff_payments_view.dart';
import '../../features/payroll/views/staff_tenant_settings_view.dart';
import '../../features/shell/contractor_shell.dart';
import '../../features/shell/staff_shell.dart';
import '../../features/sil/bindings/sil_bindings.dart';
import '../../features/sil/views/sil_houses_views.dart';
import '../../features/visits/bindings/visits_binding.dart';
import '../../features/visits/views/contractor_visit_detail_view.dart';
import '../../features/visits/views/contractor_visits_list_view.dart';
import '../../features/visits/views/staff_visits_board_view.dart';
import '../constants/app_permissions.dart';
import '../routes/app_routes.dart';
import '../routes/middlewares/auth_route_utils.dart';
import 'go_router_params.dart';
import 'shell_tab_permissions.dart';

/// Staff + contractor [ShellRoute] trees for web (Phase 2).
///
/// Child builders return **content only** — the shell wraps via [ShellRoute.builder].
List<RouteBase> buildShellGoRoutes() => [
  ShellRoute(
    builder: (context, state, child) => StaffShell(child: child),
    routes: [
      _staffTab(
        path: AppRoutes.staffHome,
        anyOf: const [AppPermissions.authSession],
        onEnter: () => HomeAlertsBinding().dependencies(),
        child: const HomeAlertsView(),
      ),
      _staffTab(
        path: AppRoutes.staffVisits,
        anyOf: kShellTabPermissions[AppRoutes.staffVisits]!.anyOf,
        onEnter: () => StaffVisitsBinding().dependencies(),
        child: const StaffVisitsBoardView(),
      ),
      _staffTab(
        path: AppRoutes.staffClients,
        anyOf: const [AppPermissions.clientsRead],
        onEnter: () => ClientsBinding().dependencies(),
        child: const ClientsListView(),
      ),
      _staffTab(
        path: AppRoutes.staffWorkforce,
        anyOf: const [AppPermissions.contractorsRead],
        onEnter: () => EngagementsBinding().dependencies(),
        child: const WorkforceListView(),
      ),
      _staffTab(
        path: AppRoutes.staffAttendanceReview,
        anyOf: kShellTabPermissions[AppRoutes.staffAttendanceReview]!.anyOf,
        onEnter: () => AttendanceReviewBinding().dependencies(),
        child: const AttendanceReviewView(),
      ),
      _staffTab(
        path: AppRoutes.staffPayments,
        anyOf: kShellTabPermissions[AppRoutes.staffPayments]!.anyOf,
        onEnter: () => StaffPaymentsBinding().dependencies(),
        child: const StaffPaymentsView(),
      ),
      _staffTab(
        path: AppRoutes.staffBillingExports,
        anyOf: kShellTabPermissions[AppRoutes.staffBillingExports]!.anyOf,
        onEnter: () => StaffInvoiceExportsBinding().dependencies(),
        child: const InvoiceExportsListView(),
      ),
      _staffTab(
        path: AppRoutes.staffCompliance,
        anyOf: kShellTabPermissions[AppRoutes.staffCompliance]!.anyOf,
        onEnter: () => StaffComplianceBinding().dependencies(),
        child: const StaffComplianceView(),
      ),
      _staffTab(
        path: AppRoutes.staffSettings,
        anyOf: const [AppPermissions.authSession],
        onEnter: () => StaffTenantSettingsBinding().dependencies(),
        child: const StaffTenantSettingsView(),
      ),
      _staffTab(
        path: AppRoutes.staffSilHouses,
        anyOf: const [AppPermissions.clientsRead],
        onEnter: () => SilHousesBinding().dependencies(),
        child: const SilHousesListView(),
      ),
      _staffTab(
        path: AppRoutes.staffJobs,
        anyOf: const [AppPermissions.jobsRead],
        onEnter: () => JobsBinding().dependencies(),
        child: const JobsListView(),
      ),
      GoRoute(
        path: AppRoutes.staffSilHouseDetail,
        redirect: (context, state) {
          final denied = redirectMissingPermission(
            route: state.matchedLocation,
            anyOf: const [
              AppPermissions.clientsRead,
              AppPermissions.clientsManage,
            ],
          );
          return denied?.name;
        },
        builder: (context, state) {
          syncGetxFromGoRouterState(state);
          SilHouseDetailBinding().dependencies();
          return const SilHouseDetailView();
        },
      ),
    ],
  ),
  ShellRoute(
    builder: (context, state, child) => ContractorShell(child: child),
    routes: [
      _contractorTab(
        path: AppRoutes.contractorHome,
        onEnter: () => HomeAlertsBinding().dependencies(),
        child: const HomeAlertsView(),
      ),
      _contractorTab(
        path: AppRoutes.contractorVisits,
        onEnter: () => ContractorVisitsBinding().dependencies(),
        child: const ContractorVisitsListView(),
      ),
      GoRoute(
        path: AppRoutes.contractorVisitDetail,
        builder: (context, state) {
          syncGetxFromGoRouterState(state);
          ContractorVisitsBinding().dependencies();
          return const ContractorVisitDetailView();
        },
      ),
      _contractorTab(
        path: AppRoutes.contractorSchedule,
        onEnter: () => ContractorScheduleBinding().dependencies(),
        child: const ContractorScheduleView(),
      ),
      _contractorTab(
        path: AppRoutes.contractorCredentials,
        onEnter: () => CredentialsBinding().dependencies(),
        child: const CredentialsListView(),
      ),
      _contractorTab(
        path: AppRoutes.contractorProfile,
        onEnter: () => ContractorProfileOpsBinding().dependencies(),
        child: const ContractorProfileOpsView(),
      ),
    ],
  ),
];

GoRoute _staffTab({
  required String path,
  required List<String> anyOf,
  required VoidCallback onEnter,
  required Widget child,
}) {
  return GoRoute(
    path: path,
    redirect: (context, state) {
      final denied = redirectMissingPermission(
        route: state.matchedLocation,
        anyOf: anyOf,
      );
      return denied?.name;
    },
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      onEnter();
      return child;
    },
  );
}

GoRoute _contractorTab({
  required String path,
  required VoidCallback onEnter,
  required Widget child,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) {
      syncGetxFromGoRouterState(state);
      onEnter();
      return child;
    },
  );
}
