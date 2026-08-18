import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/themes/app_colors.dart';
import '../../app/views/shell/responsive_scaffold.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';
import '../../shared/widgets/closed_beta_banner.dart';
import '../compliance_ops/controllers/notifications_feed_controller.dart';

/// ContractorShell nav (design §4.4).
abstract final class ContractorShellNav {
  ContractorShellNav._();

  static const destinations = <ResponsiveDestination>[
    ResponsiveDestination(icon: Icons.home_outlined, label: 'Home'),
    ResponsiveDestination(
      icon: Icons.event_available_outlined,
      label: 'Visits',
    ),
    ResponsiveDestination(
      icon: Icons.calendar_month_outlined,
      label: 'Schedule',
    ),
    ResponsiveDestination(icon: Icons.badge_outlined, label: 'Credentials'),
    ResponsiveDestination(icon: Icons.person_outline, label: 'Profile'),
  ];

  static const _routes = [
    AppRoutes.contractorHome,
    AppRoutes.contractorVisits,
    AppRoutes.contractorSchedule,
    AppRoutes.contractorCredentials,
    AppRoutes.contractorProfile,
  ];

  static int selectedIndex(String route) {
    if (route.startsWith(AppRoutes.contractorVisitDetail)) {
      return 1;
    }
    if (route.startsWith(AppRoutes.contractorOnboarding)) {
      return 0;
    }
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

class ContractorShell extends StatelessWidget {
  const ContractorShell({
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final index = ContractorShellNav.selectedIndex(
          Get.currentRoute,
        ).clamp(0, 4);
        final wide = constraints.maxWidth >= Breakpoints.tablet;

        if (wide) {
          return ResponsiveScaffold(
            destinations: ContractorShellNav.destinations,
            selectedIndex: index,
            onDestinationSelected: ContractorShellNav.navigateTo,
            child: body,
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: ContractorShellNav.navigateTo,
            backgroundColor: AppColors.cardBackground,
            indicatorColor: AppColors.primary.withValues(alpha: 0.18),
            destinations: [
              for (final d in ContractorShellNav.destinations)
                NavigationDestination(icon: Icon(d.icon), label: d.label),
            ],
          ),
        );
      },
    );
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

Widget contractorShellPage(Widget child, {bool constrainContent = true}) =>
    ContractorShell(constrainContent: constrainContent, child: child);

bool isContractorShellRoute(String? route) {
  if (route == null) return false;
  if (route.startsWith(AppRoutes.contractorOnboarding)) return false;
  if (route == AppRoutes.contractorRegister) return false;
  return route.startsWith('/contractor');
}
