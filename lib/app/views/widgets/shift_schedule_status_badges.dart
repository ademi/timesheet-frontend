import 'package:flutter/material.dart';

import '../../data/models/scheduling/board_day.dart';
import '../../data/models/scheduling/shift_status.dart';
import '../../themes/app_colors.dart';

class ShiftScheduleStatusBadges extends StatelessWidget {
  const ShiftScheduleStatusBadges({super.key, required this.day});

  final BoardDay day;

  @override
  Widget build(BuildContext context) {
    final badges = _buildBadges();
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: badges,
    );
  }

  List<Widget> _buildBadges() {
    final items = <Widget>[];

    switch (day.status) {
      case ShiftStatus.onLeave:
        items.add(_badge('On leave', AppColors.slate500, AppColors.slate100));
        break;
      case ShiftStatus.unassigned:
        items.add(_badge('Unassigned', AppColors.accentAlt, const Color(0xFFFFF3E0)));
        break;
      case ShiftStatus.dayOff:
        items.add(_badge('Off', AppColors.textMuted, AppColors.slate100));
        break;
      case ShiftStatus.assigned:
        if (day.isLate == true) {
          items.add(_badge('Late', AppColors.error, AppColors.errorBackground));
        } else if (day.clockedIn == true) {
          items.add(_badge('Clocked in', const Color(0xFF2E7D32), const Color(0xFFE8F5E9)));
        } else if (day.clockedIn == false) {
          items.add(_badge('Not in', AppColors.slate600, AppColors.slate100));
        }
        break;
    }

    if (day.conflicts.isNotEmpty) {
      items.add(_badge('Conflict', AppColors.error, AppColors.errorBackground));
    }

    return items;
  }

  Widget _badge(String label, Color foreground, Color background) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
