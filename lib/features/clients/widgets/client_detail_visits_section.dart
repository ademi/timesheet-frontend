import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../visits/data/models/visit_models.dart';

String _fmtTime(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

String _visitTimeRange(VisitOut v) {
  return '${_fmtTime(v.scheduledStart)} – ${_fmtTime(v.scheduledEnd)}';
}

class ClientDetailVisitsSection extends StatelessWidget {
  const ClientDetailVisitsSection({
    super.key,
    required this.upcoming,
    required this.past,
    required this.isLoading,
    required this.error,
    required this.truncated,
    required this.onOpen,
    this.hasVisitsAccess = true,
  });

  final List<VisitOut> upcoming;
  final List<VisitOut> past;
  final bool isLoading;
  final String? error;
  final bool truncated;
  final void Function(VisitOut visit) onOpen;
  final bool hasVisitsAccess;

  @override
  Widget build(BuildContext context) {
    if (!hasVisitsAccess &&
        !isLoading &&
        error == null &&
        upcoming.isEmpty &&
        past.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visits',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Visits require visits.read',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visits',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (isLoading) const LinearProgressIndicator(minHeight: 2),
        if (error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (truncated)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Showing first 100 visits in this window.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        const Text(
          'Upcoming',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 4),
        if (!isLoading && upcoming.isEmpty)
          const Text(
            'No upcoming visits.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final visit in upcoming) _VisitTile(visit: visit, onOpen: onOpen),
        const SizedBox(height: 12),
        const Text(
          'Past',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 4),
        if (!isLoading && past.isEmpty)
          const Text(
            'No past visits in the last 30 days.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        for (final visit in past) _VisitTile(visit: visit, onOpen: onOpen),
      ],
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit, required this.onOpen});

  final VisitOut visit;
  final void Function(VisitOut visit) onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardBackground,
      child: ListTile(
        title: Text(visit.jobTitle ?? 'Visit'),
        subtitle: Text(
          [
            if (visit.contractorName != null) visit.contractorName!,
            _visitTimeRange(visit),
            visit.status,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onOpen(visit),
      ),
    );
  }
}
