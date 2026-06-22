import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// Switches between [phone], [tablet], and [desktop] builders based on
/// available width from a [LayoutBuilder].
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.desktop,
  });

  final Widget phone;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (Breakpoints.classify(constraints.maxWidth)) {
          case DeviceClass.phone:
            return phone;
          case DeviceClass.tablet:
            return tablet ?? phone;
          case DeviceClass.desktop:
            return desktop ?? tablet ?? phone;
        }
      },
    );
  }
}
