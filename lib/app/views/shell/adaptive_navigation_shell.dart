import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../themes/app_colors.dart';
import 'responsive_scaffold.dart';

/// Adaptive shell: bottom [NavigationBar] below [Breakpoints.tablet], left
/// [NavigationRail] at/above tablet width.
///
/// All destinations stay visible — nothing is hidden behind a More menu.
class AdaptiveNavigationShell extends StatelessWidget {
  const AdaptiveNavigationShell({
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
        final wide = constraints.maxWidth >= Breakpoints.tablet;
        final index = selectedIndex < 0 ? 0 : selectedIndex;

        if (wide) {
          return ResponsiveScaffold(
            destinations: destinations,
            selectedIndex: index,
            onDestinationSelected: onDestinationSelected,
            child: child,
          );
        }

        return _NarrowNavigationShell(
          destinations: destinations,
          selectedIndex: index,
          onDestinationSelected: onDestinationSelected,
          child: child,
        );
      },
    );
  }
}

class _NarrowNavigationShell extends StatelessWidget {
  const _NarrowNavigationShell({
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
    final barSelectedIndex = selectedIndex.clamp(0, destinations.length - 1);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: barSelectedIndex,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: destinations.length > 5 ? 64 : null,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon, size: destinations.length > 5 ? 22 : 24),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}
