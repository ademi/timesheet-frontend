import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/responsive/breakpoints.dart';
import '../controllers/tutorials_controller.dart';
import 'tutorials_fab.dart';
import 'tutorials_panel.dart';

/// Staff-web-only floating tutorials FAB + panel overlay.
///
/// FAB sits on the **left**, beside the nav rail (wide) or above the bottom
/// nav (narrow), so it never covers coral Create FABs (bottom-right).
class StaffTutorialsOverlay extends StatelessWidget {
  const StaffTutorialsOverlay({super.key, required this.child});

  final Widget child;

  static const double _fabSize = 56;
  static const double _gap = 16;
  static const double _panelWidth = 380;
  static const double _panelHeight = 560;
  static const double _narrowBottomNavClearance = 88;

  /// Approx. labeled [NavigationRail] width so the FAB sits in content,
  /// beside the rail — not on top of it and not over Create FABs.
  static const double _wideNavRailClearance = 112;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    TutorialsController.ensureRegistered();
    final controller = Get.find<TutorialsController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.tablet;
        final fabLeft = wide ? _wideNavRailClearance + _gap : _gap;
        final fabBottom = wide ? _gap : _narrowBottomNavClearance;

        final panelLeft = fabLeft;
        final panelBottom = fabBottom + _fabSize + 12;
        final maxPanelHeight = (constraints.maxHeight - panelBottom - _gap)
            .clamp(280.0, _panelHeight);
        final maxPanelWidth = (constraints.maxWidth - panelLeft - _gap)
            .clamp(280.0, _panelWidth);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            Obx(() {
              if (!controller.isOpen.value) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: panelLeft,
                bottom: panelBottom,
                child: SizedBox(
                  width: maxPanelWidth,
                  height: maxPanelHeight,
                  child: TutorialsPanel(controller: controller),
                ),
              );
            }),
            Positioned(
              left: fabLeft,
              bottom: fabBottom,
              child: TutorialsFab(controller: controller),
            ),
          ],
        );
      },
    );
  }
}
