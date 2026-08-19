import 'package:flutter/material.dart';

/// Lays out [children] left-to-right in equal-width slots.
///
/// One child fills the row. Two children split 50/50. N children split 1/N.
class EqualFillRow extends StatelessWidget {
  const EqualFillRow({
    super.key,
    required this.children,
    this.spacing = 8,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fill = constraints.hasBoundedWidth &&
            constraints.maxWidth < double.infinity;
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              if (fill) Expanded(child: children[i]) else children[i],
            ],
          ],
        );
      },
    );
  }
}
