import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../themes/app_colors.dart';
import 'nav_overflow_split.dart';
import 'responsive_scaffold.dart';

/// Adaptive shell: bottom [NavigationBar] below [Breakpoints.tablet], left
/// [NavigationRail] at/above tablet width. Overflow destinations use a More menu.
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
    final split = NavOverflowSplit.split(
      destinations: destinations,
      selectedIndex: selectedIndex,
      maxVisible: NavOverflowSplit.maxBottomNavPrimary,
    );
    final hasMore = split.overflow.isNotEmpty;
    final barSelectedIndex = hasMore
        ? split.visibleSelectedIndex
        : split.visibleSelectedIndex.clamp(0, split.visible.length - 1);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: barSelectedIndex,
        onDestinationSelected: (barIndex) =>
            _onBarDestinationSelected(context, split, barIndex),
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        destinations: [
          for (final destination in split.visible)
            NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
          if (hasMore)
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
        ],
      ),
    );
  }

  void _onBarDestinationSelected(
    BuildContext context,
    NavOverflowResult split,
    int barIndex,
  ) {
    if (split.overflow.isNotEmpty && barIndex == split.visible.length) {
      _showMoreSheet(context);
      return;
    }

    final originalIndex = _originalIndex(split: split, barIndex: barIndex);
    if (originalIndex >= 0) {
      onDestinationSelected(originalIndex);
    }
  }

  int _originalIndex({
    required NavOverflowResult split,
    required int barIndex,
  }) {
    if (split.overflow.isEmpty) return barIndex;
    if (barIndex >= split.visible.length) return -1;
    final label = split.visible[barIndex].label;
    return destinations.indexWhere((d) => d.label == label);
  }

  void _showMoreSheet(BuildContext context) {
    final split = NavOverflowSplit.split(
      destinations: destinations,
      selectedIndex: selectedIndex,
      maxVisible: NavOverflowSplit.maxBottomNavPrimary,
    );

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final destination in split.overflow)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected: destinations.indexWhere(
                      (d) => d.label == destination.label,
                    ) ==
                    selectedIndex,
                onTap: () {
                  final originalIndex = destinations.indexWhere(
                    (d) => d.label == destination.label,
                  );
                  Navigator.pop(sheetContext);
                  if (originalIndex >= 0) {
                    onDestinationSelected(originalIndex);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
