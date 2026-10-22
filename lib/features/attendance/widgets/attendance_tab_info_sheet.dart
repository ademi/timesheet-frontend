import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/attendance_review_models.dart';

extension AttendanceReviewFilterLabels on AttendanceReviewFilter {
  String get shortLabel => switch (this) {
    AttendanceReviewFilter.all => 'All',
    AttendanceReviewFilter.gps => 'Location exceptions',
    AttendanceReviewFilter.variance => 'Schedule variances',
    AttendanceReviewFilter.sync => 'Sync conflicts',
  };
}

class _AttendanceTabInfoCopy {
  const _AttendanceTabInfoCopy({
    required this.title,
    required this.question,
    required this.purpose,
    required this.youCan,
    required this.notThis,
  });

  final String title;
  final String question;
  final String purpose;
  final String youCan;
  final String notThis;
}

_AttendanceTabInfoCopy _copyFor(AttendanceReviewFilter tab) {
  switch (tab) {
    case AttendanceReviewFilter.all:
      return const _AttendanceTabInfoCopy(
        title: 'All',
        question: 'What needs a decision right now?',
        purpose:
            'Every open attendance item waiting for review — location '
            'exceptions and failed clock syncs in one list.',
        youCan:
            'Scan the full queue, then open Approve / Reject on location items '
            'or Force accept / Discard on sync conflicts.',
        notThis:
            'Not a history of already-resolved items. Use the other tabs when '
            'you only want one kind of issue.',
      );
    case AttendanceReviewFilter.gps:
      return const _AttendanceTabInfoCopy(
        title: 'Location exceptions',
        question: 'Which punches have a location or GPS problem?',
        purpose:
            'Attendance exceptions raised from the worker’s clock punch — for '
            'example outside the geofence, missing GPS, or related location '
            'flags. Approve if the visit was valid; Reject if it was not.',
        youCan:
            'Review distance from site, support worker, participant, and time, then '
            'Approve or Reject with an optional note.',
        notThis:
            'Not failed clock syncs (those are Sync conflicts). Schedule '
            'variances is a narrower slice of these exceptions (late / early / '
            'outside geofence).',
      );
    case AttendanceReviewFilter.variance:
      return const _AttendanceTabInfoCopy(
        title: 'Schedule variances',
        question:
            'Which punches don’t match the expected time or place?',
        purpose:
            'A focused subset of location exceptions: outside geofence, late '
            'check-in, or early clock-out — cases where attendance differs from '
            'the planned visit window or site.',
        youCan:
            'Triage time/place mismatches first, then Approve or Reject like '
            'other location exceptions.',
        notThis:
            'Does not include sync conflicts, and may hide other exception '
            'kinds (such as missing GPS) that still appear under Location '
            'exceptions.',
      );
    case AttendanceReviewFilter.sync:
      return const _AttendanceTabInfoCopy(
        title: 'Sync conflicts',
        question: 'Which clock punches failed to sync and need a decision?',
        purpose:
            'The worker’s device recorded a punch, but it could not be applied '
            'normally (for example a conflict or failed sync). Attendance is '
            'not settled until you act.',
        youCan:
            'Force accept (with a required note) if you have verified the visit '
            'happened, or Discard if the punch should not count.',
        notThis:
            'Not location/geofence exceptions — those are under Location '
            'exceptions or Schedule variances.',
      );
  }
}

/// Bottom sheet explaining what an Attendance review filter tab is for.
Future<void> showAttendanceTabInfoSheet(
  BuildContext context, {
  required AttendanceReviewFilter tab,
}) {
  final copy = _copyFor(tab);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.question,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _InfoBlock(
                label: 'Purpose',
                body: copy.purpose,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _InfoBlock(
                label: 'What you can do',
                body: copy.youCan,
                color: AppColors.dark,
              ),
              const SizedBox(height: 12),
              _InfoBlock(
                label: 'What this is not',
                body: copy.notThis,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.body,
    required this.color,
  });

  final String label;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
