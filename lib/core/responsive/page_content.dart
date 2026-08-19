import 'package:flutter/material.dart';

import 'breakpoints.dart';
import 'max_width_box.dart';

/// Width preset for centered inner page content (not the full screen).
enum PageContentWidth {
  /// Forms, settings, single-column inputs (~760px).
  narrow,

  /// Lists with cards and mixed actions (~960px).
  workflow,

  /// Roster / wide boards (~1200). Reuses [Breakpoints.maxContent].
  wide,
}

/// Centers and caps width of inner page content: list cards, fields, buttons.
///
/// Use inside [Scaffold.body] scroll views. AppBar, FAB, and shell chrome stay
/// full width; wrap only the main content column.
class PageContent extends StatelessWidget {
  const PageContent({
    super.key,
    required this.child,
    this.width = PageContentWidth.workflow,
  });

  final Widget child;
  final PageContentWidth width;

  double get _maxWidth => switch (width) {
    PageContentWidth.narrow => Breakpoints.narrowContent,
    PageContentWidth.workflow => Breakpoints.workflowContent,
    PageContentWidth.wide => Breakpoints.maxContent,
  };

  @override
  Widget build(BuildContext context) {
    return MaxWidthBox(
      maxWidth: _maxWidth,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}
