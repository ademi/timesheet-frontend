import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';
import '../../features/visits/data/models/roster_overlay_models.dart';

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String formatAvailabilityClock(String raw) {
  final parts = raw.split(':');
  if (parts.length >= 2) {
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(hour)}:${two(minute)}';
  }
  return raw;
}

/// Read-only Mon–Sun availability windows (roster overlay DTO).
class AvailabilityRulesReadout extends StatelessWidget {
  const AvailabilityRulesReadout({super.key, required this.rules});

  final List<AvailabilityRuleOut> rules;

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return const Text(
        'No weekly availability set.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    final sorted = [...rules]..sort((a, b) {
      final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (byDay != 0) return byDay;
      return a.startTime.compareTo(b.startTime);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final rule in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(
                    _weekdayShort[rule.dayOfWeek.clamp(0, 6)],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${formatAvailabilityClock(rule.startTime)}–${formatAvailabilityClock(rule.endTime)}',
                ),
              ],
            ),
          ),
      ],
    );
  }
}
