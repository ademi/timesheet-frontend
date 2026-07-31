import 'compliance_ops_models.dart';

const _knownTitles = <String, String>{
  'visit.assigned': 'Visit assigned',
  'engagement.invited': 'Contractor invited',
  'engagement.accepted': 'Contractor accepted',
  'sharing.access_requested': 'Access requested',
};

const _monthLabels = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String notificationTitle(String eventType, Map<String, dynamic> payload) {
  final base = _knownTitles[eventType] ?? _fallbackTitle(eventType);
  final detail = payload['job_title'] ??
      payload['client_name'] ??
      payload['credential_type'];
  if (detail != null && detail.toString().trim().isNotEmpty) {
    return '$base · $detail';
  }
  return base;
}

String _fallbackTitle(String eventType) {
  final normalized = eventType.replaceAll('.', ' ').replaceAll('_', ' ');
  if (normalized.isEmpty) return eventType;
  return normalized[0].toUpperCase() + normalized.substring(1);
}

String formatNotificationTime(DateTime createdAt) {
  final local = createdAt.toLocal();
  final diff = DateTime.now().difference(local);

  if (!diff.isNegative) {
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
  }

  final month = _monthLabels[local.month - 1];
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month ${local.day}, $hour:$minute';
}

String _dedupeKey(NotificationEventOut event) {
  final entity = event.payload['visit_id']?.toString() ??
      event.payload['job_title']?.toString() ??
      '';
  final at = event.createdAt.toLocal();
  final second = DateTime(
    at.year,
    at.month,
    at.day,
    at.hour,
    at.minute,
    at.second,
  ).toIso8601String();
  return '${event.eventType}|$entity|$second';
}

List<NotificationEventOut> dedupeNotificationEvents(
  List<NotificationEventOut> input,
) {
  final seen = <String>{};
  final out = <NotificationEventOut>[];

  for (final event in input) {
    if (seen.add(_dedupeKey(event))) {
      out.add(event);
    }
  }

  return out;
}
