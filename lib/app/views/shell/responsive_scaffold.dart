import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../themes/app_colors.dart';
import 'nav_overflow_split.dart';

/// A top-level navigation destination shown in [ResponsiveScaffold]'s rail.
class ResponsiveDestination {
  const ResponsiveDestination({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

/// Wide-screen shell: [NavigationRail] + content.
///
/// Used by [AdaptiveNavigationShell] at widths >= [Breakpoints.tablet].
/// Overflow destinations collapse into a More menu on the rail.
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
        final index = selectedIndex < 0 ? 0 : selectedIndex;
        final split = NavOverflowSplit.split(
          destinations: destinations,
          selectedIndex: index,
          maxVisible: NavOverflowSplit.maxRailPrimary,
        );
        final hasMore = split.overflow.isNotEmpty;
        final railSelectedIndex = hasMore
            ? split.visibleSelectedIndex
            : split.visibleSelectedIndex.clamp(0, split.visible.length - 1);
        final compact = constraints.maxWidth < Breakpoints.tablet;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationRail(
              selectedIndex: railSelectedIndex,
              onDestinationSelected: (railIndex) => _onRailDestinationSelected(
                context,
                split: split,
                railIndex: railIndex,
                hasMore: hasMore,
              ),
              labelType:
                  compact
                      ? NavigationRailLabelType.selected
                      : NavigationRailLabelType.all,
              groupAlignment: -1,
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
                for (final destination in split.visible)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    label: Text(destination.label),
                  ),
                if (hasMore)
                  const NavigationRailDestination(
                    icon: Icon(Icons.more_horiz),
                    label: Text('More'),
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

  void _onRailDestinationSelected(
    BuildContext context, {
    required NavOverflowResult split,
    required int railIndex,
    required bool hasMore,
  }) {
    if (hasMore && railIndex == split.visible.length) {
      _showMoreSheet(context, split.overflow);
      return;
    }

    final label = split.visible[railIndex].label;
    final originalIndex = destinations.indexWhere((d) => d.label == label);
    if (originalIndex >= 0) {
      onDestinationSelected(originalIndex);
    }
  }

  void _showMoreSheet(
    BuildContext context,
    List<ResponsiveDestination> overflow,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final destination in overflow)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                selected:
                    destinations.indexWhere(
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
