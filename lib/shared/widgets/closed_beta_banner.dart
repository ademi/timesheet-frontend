import 'package:flutter/material.dart';

class ClosedBetaBanner extends StatelessWidget {
  const ClosedBetaBanner({super.key});

  static const message =
      'Closed beta — interim privacy and terms. Not counsel-approved.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
          ),
        ),
      ),
    );
  }
}
