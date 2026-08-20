import 'responsive_scaffold.dart';

class NavOverflowResult {
  const NavOverflowResult({
    required this.visible,
    required this.overflow,
    required this.moreSelected,
    required this.visibleSelectedIndex,
  });

  final List<ResponsiveDestination> visible;
  final List<ResponsiveDestination> overflow;
  final bool moreSelected;
  final int visibleSelectedIndex;
}

abstract final class NavOverflowSplit {
  NavOverflowSplit._();

  static const maxBottomNavPrimary = 4;
  static const maxRailPrimary = 6;

  static bool isSelectionInOverflow({
    required List<ResponsiveDestination> destinations,
    required int selectedIndex,
    required int maxVisible,
  }) {
    if (selectedIndex < 0 || selectedIndex >= destinations.length) return false;
    if (destinations.length <= maxVisible) return false;
    return selectedIndex >= maxVisible;
  }

  static NavOverflowResult split({
    required List<ResponsiveDestination> destinations,
    required int selectedIndex,
    required int maxVisible,
  }) {
    if (destinations.length <= maxVisible) {
      return NavOverflowResult(
        visible: destinations,
        overflow: const [],
        moreSelected: false,
        visibleSelectedIndex: selectedIndex.clamp(0, destinations.length - 1),
      );
    }

    final overflow = destinations.sublist(maxVisible);
    var visible = destinations.sublist(0, maxVisible);

    var visibleSelectedIndex = selectedIndex;
    var moreSelected = false;

    if (selectedIndex >= maxVisible) {
      moreSelected = true;
      visibleSelectedIndex = maxVisible; // More slot index in NavigationBar
    } else {
      moreSelected = false;
      visibleSelectedIndex = selectedIndex;
    }

    return NavOverflowResult(
      visible: visible,
      overflow: overflow,
      moreSelected: moreSelected,
      visibleSelectedIndex: visibleSelectedIndex,
    );
  }
}
