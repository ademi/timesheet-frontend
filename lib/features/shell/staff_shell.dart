import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/views/shell/responsive_scaffold.dart';
import '../../core/services/session_service.dart';
import '../../shared/widgets/closed_beta_banner.dart';
import '../compliance_ops/controllers/notifications_feed_controller.dart';

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
      icon: Icons.event_available_outlined,
      label: 'Roster',
      route: AppRoutes.staffVisits,
      anyOf: [AppPermissions.visitsRead, AppPermissions.shiftsRead],
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
    final filtered = Get.isRegistered<SessionService>()
        ? _all
            .where((d) => Get.find<SessionService>().hasAny(d.anyOf))
            .toList(growable: false)
        : <_StaffDest>[];

    final hasHome = filtered.any((d) => d.route == AppRoutes.staffHome);
    if (filtered.isEmpty || !hasHome) {
      return _all
          .where((d) => d.anyOf.contains(AppPermissions.authSession))
          .toList(growable: false);
    }
    return filtered;
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

  static List<ResponsiveDestination> destinations() =>
      _visible()
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
    NotificationsFeedController.ensureRegistered();
    final body = _shellBody(child);
    return Obx(() {
      if (Get.isRegistered<SessionService>()) {
        final session = Get.find<SessionService>();
        session.isHydrating.value;
        session.tenantId.value;
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final destinations = StaffShellNav.destinations();
          final index = StaffShellNav.selectedIndex(Get.currentRoute);

          if (destinations.isEmpty) {
            return Column(
              children: [
                const MaterialBanner(
                  content: Text(
                    'Permissions still loading — refresh or sign in again.',
                  ),
                  actions: [SizedBox.shrink()],
                ),
                Expanded(child: body),
              ],
            );
          }

          // Always left-side nav (rail). Compact labels on narrow widths.
          return ResponsiveScaffold(
            destinations: destinations,
            selectedIndex: index,
            onDestinationSelected: StaffShellNav.navigateTo,
            child: body,
          );
        },
      );
    });
  }
}

Widget _shellBody(Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [const ClosedBetaBanner(), Expanded(child: child)],
);

Widget staffShellPage(Widget child) => StaffShell(child: child);

bool isStaffRoute(String? route) {
  if (route == null) return false;
  return route.startsWith('/staff');
}
