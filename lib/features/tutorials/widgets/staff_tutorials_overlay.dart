import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/responsive/breakpoints.dart';
import '../controllers/tutorials_controller.dart';
import 'tutorials_fab.dart';
import 'tutorials_panel.dart';

/// Staff-web-only floating tutorials FAB + panel overlay.
///
/// Wide layouts: FAB bottom-right. Narrow: FAB bottom-left above bottom nav
/// so it does not collide with coral Create FABs (typically bottom-right).
class StaffTutorialsOverlay extends StatelessWidget {
  const StaffTutorialsOverlay({super.key, required this.child});

  final Widget child;

  static const double _fabSize = 56;
  static const double _gap = 16;
  static const double _panelWidth = 380;
  static const double _panelHeight = 560;
  static const double _narrowBottomNavClearance = 88;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    TutorialsController.ensureRegistered();
    final controller = Get.find<TutorialsController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.tablet;
        final fabLeft = wide ? null : _gap;
        final fabRight = wide ? _gap : null;
        final fabBottom = wide ? _gap : _narrowBottomNavClearance;

        final panelRight = wide ? _gap : null;
        final panelLeft = wide ? null : _gap;
        final panelBottom =
            (wide ? _gap : _narrowBottomNavClearance) + _fabSize + 12;
        final maxPanelHeight = (constraints.maxHeight - panelBottom - _gap)
            .clamp(280.0, _panelHeight);
        final maxPanelWidth =
            (constraints.maxWidth - (_gap * 2)).clamp(280.0, _panelWidth);

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
                right: panelRight,
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
              right: fabRight,
              bottom: fabBottom,
              child: TutorialsFab(controller: controller),
            ),
          ],
        );
      },
    );
  }
}
