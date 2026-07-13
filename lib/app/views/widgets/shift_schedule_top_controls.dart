import 'package:flutter/material.dart';

import '../../themes/app_colors.dart';
import 'shift_schedule_summary_chips.dart';
import 'shift_schedule_week_navigator.dart';

class ShiftScheduleTopControls extends StatelessWidget {
  const ShiftScheduleTopControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShiftScheduleWeekNavigator(),
          SizedBox(height: 12),
          ShiftScheduleViewToggle(),
        ],
      ),
    );
  }
}
