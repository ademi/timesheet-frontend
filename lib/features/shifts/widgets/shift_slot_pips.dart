import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

/// Slot fill indicators for roster shift cards.
class ShiftSlotPips extends StatelessWidget {
  const ShiftSlotPips({
    super.key,
    required this.requiredSlots,
    required this.filledSlots,
  });

  final int requiredSlots;
  final int filledSlots;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < requiredSlots; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              i < filledSlots ? Icons.circle : Icons.circle_outlined,
              key: Key(
                i < filledSlots ? 'slot-pip-filled' : 'slot-pip-open',
              ),
              size: 12,
              color: i < filledSlots ? AppColors.success : AppColors.openSlot,
            ),
          ),
      ],
    );
  }
}
