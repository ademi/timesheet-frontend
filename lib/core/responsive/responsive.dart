import 'package:flutter/material.dart';

import 'breakpoints.dart';

extension ResponsiveContext on BuildContext {
  /// Classifies device from a [LayoutBuilder]'s `constraints.maxWidth`.
  ///
  /// Prefer this (or the `*For` helpers) for structural layout decisions.
  DeviceClass deviceClassFor(double maxWidth) => Breakpoints.classify(maxWidth);

  bool isPhoneFor(double maxWidth) =>
      deviceClassFor(maxWidth) == DeviceClass.phone;

  bool isTabletFor(double maxWidth) =>
      deviceClassFor(maxWidth) == DeviceClass.tablet;

  bool isDesktopFor(double maxWidth) =>
      deviceClassFor(maxWidth) == DeviceClass.desktop;

  /// Viewport-based convenience getters. For structural branching inside a
  /// screen, pass `constraints.maxWidth` to the `*For` helpers instead.
  DeviceClass get deviceClass => deviceClassFor(_viewportWidth);

  bool get isPhone => isPhoneFor(_viewportWidth);

  bool get isTablet => isTabletFor(_viewportWidth);

  bool get isDesktop => isDesktopFor(_viewportWidth);

  double get maxContentWidth => Breakpoints.maxContent;

  double get _viewportWidth => MediaQuery.sizeOf(this).width;
}
