import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Hub-card grid that reflows by available width: 1 / 2 / 3 columns.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.childAspectRatio,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final aspectRatio = childAspectRatio ?? (columns == 1 ? 3.5 : 2.8);
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: runSpacing,
          crossAxisSpacing: spacing,
          shrinkWrap: shrinkWrap,
          physics: physics,
          padding: padding,
          childAspectRatio: aspectRatio,
          children: children,
        );
      },
    );
  }

  int _columnCount(double width) {
    switch (Breakpoints.classify(width)) {
      case DeviceClass.phone:
        return 1;
      case DeviceClass.tablet:
        return 2;
      case DeviceClass.desktop:
        return 3;
    }
  }
}
