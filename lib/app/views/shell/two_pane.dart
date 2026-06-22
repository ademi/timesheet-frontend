import 'package:flutter/material.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../themes/app_colors.dart';

/// Master/detail split for wide screens (≥ [Breakpoints.tablet]).
class TwoPane extends StatelessWidget {
  const TwoPane({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 380,
  });

  final Widget master;
  final Widget detail;
  final double masterWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: masterWidth,
          child: master,
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: detail),
      ],
    );
  }
}

/// Empty-state panel shown in the detail pane before a selection.
class PaneDetailPlaceholder extends StatelessWidget {
  const PaneDetailPlaceholder({
    super.key,
    this.message = 'Select an item to view details',
    this.icon = Icons.touch_app_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether to use master/detail layout for the given width.
bool useTwoPaneLayout(double maxWidth) => maxWidth >= Breakpoints.tablet;
