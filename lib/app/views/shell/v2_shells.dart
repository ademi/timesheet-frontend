import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/permission_helpers.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/services/token_storage.dart';
import '../../routes/app_routes.dart';
import 'responsive_scaffold.dart';

/// DOMAIN_V2 admin dual-shell destinations.
abstract final class AdminV2ShellRoutes {
  AdminV2ShellRoutes._();

  static const destinations = <ResponsiveDestination>[
    ResponsiveDestination(icon: Icons.home_outlined, label: 'Hub'),
    ResponsiveDestination(icon: Icons.groups_outlined, label: 'Team'),
    ResponsiveDestination(icon: Icons.handshake_outlined, label: 'Contractors'),
    ResponsiveDestination(icon: Icons.people_outline, label: 'Clients'),
    ResponsiveDestination(icon: Icons.work_outline, label: 'Jobs'),
    ResponsiveDestination(icon: Icons.payments_outlined, label: 'Payments'),
    ResponsiveDestination(icon: Icons.description_outlined, label: 'Forms'),
    ResponsiveDestination(icon: Icons.settings_outlined, label: 'Settings'),
  ];

  static const _routes = AdminRoutes.all;

  static int selectedIndex(String route) {
    final i = _routes.indexWhere((r) => route.startsWith(r));
    return i < 0 ? 0 : i;
  }

  static void navigateTo(int index) {
    if (index < 0 || index >= _routes.length) return;
    final route = _routes[index];
    if (Get.currentRoute == route) return;
    Get.offNamed(route);
  }
}

class AdminV2Shell extends StatelessWidget {
  const AdminV2Shell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      destinations: AdminV2ShellRoutes.destinations,
      selectedIndex: AdminV2ShellRoutes.selectedIndex(Get.currentRoute),
      onDestinationSelected: AdminV2ShellRoutes.navigateTo,
      child: child,
    );
  }
}

Widget adminV2ShellPage(Widget child) => AdminV2Shell(child: child);

/// DOMAIN_V2 contractor dual-shell destinations.
abstract final class ContractorShellRoutes {
  ContractorShellRoutes._();

  static const destinations = <ResponsiveDestination>[
    ResponsiveDestination(
      icon: Icons.event_available_outlined,
      label: 'Visits',
    ),
    ResponsiveDestination(
      icon: Icons.calendar_month_outlined,
      label: 'Timetable',
    ),
    ResponsiveDestination(
      icon: Icons.upload_file_outlined,
      label: 'Documents',
    ),
    ResponsiveDestination(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Payments',
    ),
    ResponsiveDestination(icon: Icons.swap_horiz_outlined, label: 'Tenants'),
    ResponsiveDestination(icon: Icons.person_outline, label: 'Profile'),
  ];

  static const _routes = [
    ContractorRoutes.visits,
    ContractorRoutes.timetable,
    ContractorRoutes.documents,
    ContractorRoutes.payments,
    ContractorRoutes.switchTenant,
    ContractorRoutes.profile,
  ];

  static int selectedIndex(String route) {
    if (route.startsWith(ContractorRoutes.visitDetail) ||
        route.startsWith(ContractorRoutes.engagementAccept)) {
      return 0;
    }
    final i = _routes.indexWhere((r) => route.startsWith(r));
    return i < 0 ? 0 : i;
  }

  static void navigateTo(int index) {
    if (index < 0 || index >= _routes.length) return;
    final route = _routes[index];
    if (!Get.isRegistered<TokenStorage>()) {
      Get.offNamed(route);
      return;
    }
    final storage = Get.find<TokenStorage>();
    if (route == ContractorRoutes.documents &&
        !PermissionHelpers.canUploadDocuments(storage) &&
        !storage.hasPermission('auth.session')) {
      return;
    }
    if (Get.currentRoute == route) return;
    Get.offNamed(route);
  }
}

class ContractorShell extends StatelessWidget {
  const ContractorShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      destinations: ContractorShellRoutes.destinations,
      selectedIndex: ContractorShellRoutes.selectedIndex(Get.currentRoute),
      onDestinationSelected: ContractorShellRoutes.navigateTo,
      child: child,
    );
  }
}

Widget contractorShellPage(Widget child) => ContractorShell(child: child);

bool isAdminV2Route(String? route) {
  if (route == null || !FeatureFlags.domainV2) return false;
  return AdminRoutes.all.any((r) => route.startsWith(r));
}

bool isContractorV2Route(String? route) {
  if (route == null || !FeatureFlags.domainV2) return false;
  return ContractorRoutes.all.any((r) => route.startsWith(r));
}
