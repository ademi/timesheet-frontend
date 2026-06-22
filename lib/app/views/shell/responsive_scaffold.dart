import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../themes/app_colors.dart';

/// A top-level navigation destination shown in [ResponsiveScaffold]'s rail.
class ResponsiveDestination {
  const ResponsiveDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// Wide-screen shell: [NavigationRail] + content. Below [Breakpoints.tablet] renders
/// [child] only (phone / narrow tablet unchanged).
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.child,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final Widget child;
  final List<ResponsiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.tablet) {
          return child;
        }

        final index = selectedIndex < 0 ? 0 : selectedIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppColors.cardBackground,
              indicatorColor: AppColors.primary.withValues(alpha: 0.18),
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedIconTheme: IconThemeData(color: Colors.grey.shade600),
              unselectedLabelTextStyle: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 11,
              ),
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
