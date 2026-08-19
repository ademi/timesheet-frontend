import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

class AgendaVisit {
  const AgendaVisit({
    required this.start,
    required this.end,
    required this.title,
    required this.status,
    required this.onOpen,
  });

  final DateTime start;
  final DateTime end;
  final String title;
  final String status;
  final VoidCallback onOpen;
}

const _weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _fmtAgendaDay(DateTime day) {
  final l = day.toLocal();
  final wd = _weekdayShort[(l.weekday - 1) % 7];
  return '$wd ${l.day}/${l.month}';
}

String _localDayKey(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

String _fmtTime(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}';
}

bool _isSameLocalDay(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// Groups visits by local calendar day for a read-only timetable.
class VisitDayAgenda extends StatelessWidget {
  const VisitDayAgenda({super.key, required this.visits});

  final List<AgendaVisit> visits;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const Text(
        'No visits in this window.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }

    final grouped = <String, List<AgendaVisit>>{};
    for (final visit in visits) {
      grouped.putIfAbsent(_localDayKey(visit.start), () => []).add(visit);
    }
    final keys = grouped.keys.toList()..sort();
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in keys) ...[
          _DayHeader(
            label: _fmtAgendaDay(grouped[key]!.first.start),
            isToday: _isSameLocalDay(grouped[key]!.first.start, today),
            visitCount: grouped[key]!.length,
          ),
          for (final visit in _sortedByStart(grouped[key]!))
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppColors.cardBackground,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                title: Text(
                  visit.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${_fmtTime(visit.start)} – ${_fmtTime(visit.end)} · ${visit.status}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: visit.onOpen,
              ),
            ),
        ],
      ],
    );
  }
}

List<AgendaVisit> _sortedByStart(List<AgendaVisit> visits) {
  final copy = [...visits]..sort((a, b) => a.start.compareTo(b.start));
  return copy;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.label,
    required this.isToday,
    required this.visitCount,
  });

  final String label;
  final bool isToday;
  final int visitCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: isToday ? AppColors.primary : AppColors.textDark,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (visitCount > 0)
            Text(
              '$visitCount',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}
