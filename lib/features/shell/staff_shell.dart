import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/constants/app_permissions.dart';
import '../../app/routes/app_routes.dart';
import '../../app/views/shell/responsive_scaffold.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import '../../core/services/session_service.dart';
import '../../shared/widgets/closed_beta_banner.dart';
import '../compliance_ops/controllers/notifications_feed_controller.dart';

/// StaffShell nav (design §4.3).
abstract final class StaffShellNav {
  StaffShellNav._();

  /// Compliance stays in routes for later; hide it from the staff menu for now.
  static const showComplianceNav = false;

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
      showInNav: showComplianceNav,
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
            .where(
              (d) => d.showInNav && Get.find<SessionService>().hasAny(d.anyOf),
            )
            .toList(growable: false)
        : <_StaffDest>[];

    final hasHome = filtered.any((d) => d.route == AppRoutes.staffHome);
    if (filtered.isEmpty || !hasHome) {
      return _all
          .where(
            (d) =>
                d.showInNav && d.anyOf.contains(AppPermissions.authSession),
          )
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
    this.showInNav = true,
  });

  final IconData icon;
  final String label;
  final String route;
  final List<String> anyOf;
  final bool showInNav;
}

class StaffShell extends StatelessWidget {
  const StaffShell({
    super.key,
    required this.child,
    this.constrainContent = true,
  });

  final Widget child;
  final bool constrainContent;

  @override
  Widget build(BuildContext context) {
    NotificationsFeedController.ensureRegistered();
    final body = _shellBody(child, constrainContent: constrainContent);
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

Widget _shellBody(Widget child, {required bool constrainContent}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const ClosedBetaBanner(),
    Expanded(
      child:
          constrainContent
              ? LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < Breakpoints.tablet) {
                    return child;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: MaxWidthBox(
                      maxWidth: Breakpoints.maxContent,
                      child: child,
                    ),
                  );
                },
              )
              : child,
    ),
  ],
);

Widget staffShellPage(Widget child, {bool constrainContent = true}) =>
    StaffShell(constrainContent: constrainContent, child: child);

bool isStaffRoute(String? route) {
  if (route == null) return false;
  return route.startsWith('/staff');
}
