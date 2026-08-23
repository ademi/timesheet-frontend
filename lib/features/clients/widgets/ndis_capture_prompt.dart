import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

/// Soft prompt when a Patient client has no NDIS number on file.
class NdisCapturePrompt extends StatelessWidget {
  const NdisCapturePrompt({
    super.key,
    this.onAddDetails,
  });

  final VoidCallback? onAddDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NDIS number not captured',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.openSlot,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Patient clients need an NDIS number for plan-manager exports and demos. '
            'Add it on the Details tab.',
            style: TextStyle(fontSize: 13),
          ),
          if (onAddDetails != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onAddDetails,
                child: const Text('Open Details tab'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
