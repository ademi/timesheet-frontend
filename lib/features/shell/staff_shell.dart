import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/views/shell/responsive_scaffold.dart';
import '../../core/services/session_service.dart';
import 'shell_stub_page.dart';

/// StaffShell nav (design §4.3).
abstract final class StaffShellNav {
  StaffShellNav._();

  static const _all = <_StaffDest>[
    _StaffDest(
      icon: Icons.home_outlined,
      label: 'Home',
      route: AppRoutes.staffHome,
      anyOf: [AppPermissions.authSession],
    ),
    _StaffDest(
      icon: Icons.groups_outlined,
      label: 'Workforce',
      route: AppRoutes.staffWorkforce,
      anyOf: [AppPermissions.contractorsRead],
    ),
    _StaffDest(
      icon: Icons.people_outline,
      label: 'Clients',
      route: AppRoutes.staffClients,
      anyOf: [AppPermissions.clientsRead],
    ),
    _StaffDest(
      icon: Icons.work_outline,
      label: 'Jobs',
      route: AppRoutes.staffJobs,
      anyOf: [AppPermissions.jobsRead],
    ),
    _StaffDest(
      icon: Icons.event_available_outlined,
      label: 'Visits',
      route: AppRoutes.staffVisits,
      anyOf: [AppPermissions.visitsRead],
    ),
    _StaffDest(
      icon: Icons.payments_outlined,
      label: 'Payments',
      route: AppRoutes.staffPayments,
      anyOf: [AppPermissions.paymentsView],
    ),
    _StaffDest(
      icon: Icons.verified_user_outlined,
      label: 'Compliance',
      route: AppRoutes.staffCompliance,
      anyOf: [
        AppPermissions.credentialsReview,
        AppPermissions.complianceRightsManage,
        AppPermissions.complianceIncidentsManage,
        AppPermissions.complianceAuditView,
      ],
    ),
    _StaffDest(
      icon: Icons.settings_outlined,
      label: 'Settings',
      route: AppRoutes.staffSettings,
      anyOf: [AppPermissions.authSession],
    ),
  ];

  static List<_StaffDest> _visible() {
    if (!Get.isRegistered<SessionService>()) {
      return _all.where((d) => d.route == AppRoutes.staffHome).toList();
    }
    final session = Get.find<SessionService>();
    return _all.where((d) => session.hasAny(d.anyOf)).toList(growable: false);
  }

  static int selectedIndex(String route) {
    final items = _visible();
    final i = items.indexWhere((d) => route.startsWith(d.route));
    return i < 0 ? 0 : i;
  }

  static void navigateTo(int index) {
    final items = _visible();
    if (index < 0 || index >= items.length) return;
    final route = items[index].route;
    if (Get.currentRoute == route) return;
    Get.offNamed(route);
  }

  static List<ResponsiveDestination> destinations() => _visible()
      .map((d) => ResponsiveDestination(icon: d.icon, label: d.label))
      .toList();
}

class _StaffDest {
  const _StaffDest({
    required this.icon,
    required this.label,
    required this.route,
    required this.anyOf,
  });

  final IconData icon;
  final String label;
  final String route;
  final List<String> anyOf;
}

class StaffShell extends StatelessWidget {
  const StaffShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destinations = StaffShellNav.destinations();
    if (destinations.isEmpty) return child;
    return ResponsiveScaffold(
      destinations: destinations,
      selectedIndex: StaffShellNav.selectedIndex(Get.currentRoute),
      onDestinationSelected: StaffShellNav.navigateTo,
      child: child,
    );
  }
}

Widget staffShellPage(Widget child) => StaffShell(child: child);

bool isStaffRoute(String? route) {
  if (route == null) return false;
  return route.startsWith('/staff');
}

/// Convenience stub wrappers for GetPages.
Widget staffHomeStub() =>
    staffShellPage(const ShellStubPage(title: 'Staff home'));
Widget staffWorkforceStub() =>
    staffShellPage(const ShellStubPage(title: 'Workforce'));
Widget staffClientsStub() =>
    staffShellPage(const ShellStubPage(title: 'Clients'));
