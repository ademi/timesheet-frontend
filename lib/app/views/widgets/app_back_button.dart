import 'package:flutter/material.dart';

import '../../routes/app_navigation.dart';
import '../../routes/app_routes.dart';

/// Refresh-aware back button for use as an [AppBar.leading].
///
/// On web a browser refresh resets GetX's in-memory navigation stack to a single
/// route, so the default [AppBar] back arrow (which only shows when
/// `Navigator.canPop()` is true) disappears. This widget is *always* rendered and:
///   * pops the route normally when a stack exists (identical to `Get.back()`), or
///   * navigates to a logical [fallbackRoute] when the stack is empty
///     (the post-refresh case), so the button stays visible and functional.
///
/// Works unchanged on mobile: there the stack is never reset, `canPop()` is true,
/// and the fallback branch is never reached.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.fallbackRoute = AppRoutes.adminPanel});

  /// Logical parent to land on when nothing can be popped (post-refresh on web).
  final String fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => backOrToParent(fallbackRoute),
    );
  }
}
