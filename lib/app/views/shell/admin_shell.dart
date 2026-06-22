import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'admin_shell_routes.dart';
import 'responsive_scaffold.dart';

/// Wraps an admin-area page with [ResponsiveScaffold] on wide screens (≥ tablet bp).
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      destinations: AdminShellRoutes.destinations,
      selectedIndex: AdminShellRoutes.selectedIndex(Get.currentRoute),
      onDestinationSelected: AdminShellRoutes.navigateTo,
      child: child,
    );
  }
}

/// Wraps a page widget in [AdminShell] for use in [GetPage] definitions.
Widget adminShellPage(Widget child) => AdminShell(child: child);
