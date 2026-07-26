import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../routes/app_routes.dart';
import 'responsive_scaffold.dart';

/// Rail destinations for the legacy admin shell (S9: payroll product removed).
abstract final class AdminShellRoutes {
  AdminShellRoutes._();

  static const destinations = <ResponsiveDestination>[
    ResponsiveDestination(
      icon: Icons.groups_rounded,
      label: 'Hub',
    ),
  ];

  static const _hubRoutes = {
    AppRoutes.adminPanel,
  };

  static bool isShellRoute(String? route) {
    if (route == null) return false;
    return _hubRoutes.contains(route);
  }

  static int selectedIndex(String? route) {
    if (route == null) return -1;
    if (_hubRoutes.contains(route)) return 0;
    return -1;
  }

  static int sectionForRoute(String? route) => selectedIndex(route);

  static String routeForIndex(int index) {
    return AppRoutes.adminPanel;
  }

  static void navigateTo(int index) {
    final target = routeForIndex(index);
    if (Get.currentRoute == target) return;
    Get.offAllNamed(target);
  }
}
