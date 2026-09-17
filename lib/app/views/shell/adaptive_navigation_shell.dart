import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../themes/app_colors.dart';
import 'responsive_scaffold.dart';

/// Adaptive shell: bottom [NavigationBar] below [Breakpoints.tablet], left
/// [NavigationRail] at/above tablet width.
///
/// On narrow layouts, when [destinations] exceed [narrowPrimaryCount], the bar
/// shows the first [narrowPrimaryCount] items plus a **More** tab that opens an
/// overflow sheet for the rest. Wide layouts still show every destination.
class AdaptiveNavigationShell extends StatelessWidget {
  const AdaptiveNavigationShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.narrowPrimaryCount = 4,
  });

  final Widget child;
  final List<ResponsiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Max destinations pinned to the phone bottom bar before **More**.
  final int narrowPrimaryCount;

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
          primaryCount: narrowPrimaryCount,
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
    required this.primaryCount,
  });

  final Widget child;
  final List<ResponsiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int primaryCount;

  bool get _usesMore => destinations.length > primaryCount;

  List<ResponsiveDestination> get _primary {
    if (!_usesMore) return destinations;
    return destinations.take(primaryCount).toList(growable: false);
  }

  List<ResponsiveDestination> get _overflow {
    if (!_usesMore) return const [];
    return destinations.skip(primaryCount).toList(growable: false);
  }

  int get _barSelectedIndex {
    if (!_usesMore) {
      return selectedIndex.clamp(0, destinations.length - 1);
    }
    if (selectedIndex < primaryCount) return selectedIndex;
    // Overflow route → highlight More (last bar slot).
    return primaryCount;
  }

  Future<void> _openMore(BuildContext context) async {
    final overflow = _overflow;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'More',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              for (var i = 0; i < overflow.length; i++)
                ListTile(
                  leading: Icon(overflow[i].icon),
                  title: Text(overflow[i].label),
                  selected: selectedIndex == primaryCount + i,
                  onTap: () => Navigator.pop(ctx, primaryCount + i),
                ),
            ],
          ),
        );
      },
    );
    if (chosen != null) onDestinationSelected(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final primary = _primary;
    final barIndex = _barSelectedIndex;
    final barDestinations = <NavigationDestination>[
      for (final destination in primary)
        NavigationDestination(icon: Icon(destination.icon), label: destination.label),
      if (_usesMore)
        const NavigationDestination(
          icon: Icon(Icons.more_horiz),
          label: 'More',
        ),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: barIndex.clamp(0, barDestinations.length - 1),
        onDestinationSelected: (i) {
          if (_usesMore && i == primaryCount) {
            _openMore(context);
            return;
          }
          onDestinationSelected(i);
        },
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: barDestinations,
      ),
    );
  }
}
