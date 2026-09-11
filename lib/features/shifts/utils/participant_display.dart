/// Display helpers for roster tiles and staff participant labels.

/// Filters to participants whose status is `active`.
///
/// Supports model instances with a `status` getter, or [Map] rows with a
/// `'status'` key.
List<T> activeParticipants<T>(List<T> participants) {
  return [
    for (final participant in participants)
      if (_statusOf(participant) == 'active') participant,
  ];
}

String staffParticipantLabel(int workerCount, int n) => '$workerCount:$n';

/// Roster tile label: up to two first names, then `+N more`.
///
/// When two visible names share a first name, those rows use a truncated full
/// name (first name + last-name initials) instead.
String rosterTileLabel(Iterable<String> displayNames) {
  final names = [
    for (final name in displayNames)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  if (names.isEmpty) return '';

  final visibleCount = names.length == 1 ? 1 : 2;
  final visible = names.take(visibleCount).toList(growable: false);
  final firstNames = visible.map(_firstName).toList(growable: false);

  final counts = <String, int>{};
  for (final first in firstNames) {
    counts[first] = (counts[first] ?? 0) + 1;
  }

  final labels = <String>[
    for (var i = 0; i < visible.length; i++)
      (counts[firstNames[i]] ?? 0) > 1
          ? _truncatedFullName(visible[i])
          : firstNames[i],
  ];

  final more = names.length - visible.length;
  if (more > 0) {
    return '${labels.join(', ')} +$more more';
  }
  return labels.join(', ');
}

String _statusOf(Object? participant) {
  if (participant is Map) {
    return '${participant['status'] ?? ''}';
  }
  final dynamic row = participant;
  return '${row.status ?? ''}';
}

String _firstName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  return parts.first;
}

/// First name plus initials of remaining tokens (e.g. `Maya Smith` → `Maya S`).
String _truncatedFullName(String fullName) {
  final parts = fullName.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts.first;
  final initials = parts
      .skip(1)
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .join();
  if (initials.isEmpty) return parts.first;
  return '${parts.first} $initials';
}
