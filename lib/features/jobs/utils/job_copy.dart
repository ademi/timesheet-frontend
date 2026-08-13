String kindLabel(String kind) => switch (kind) {
      'standing' => 'Ongoing support',
      'ad_hoc' => 'One-off',
      _ => kind,
    };

String jobStatusLabel(String status) => switch (status) {
      'open' => 'Open',
      'closed' => 'Ended',
      'cancelled' => 'Cancelled',
      _ => status,
    };

String locationModeLabel(String mode) => switch (mode) {
      'site' => "Client's home",
      'branch' => 'Branch',
      _ => mode,
    };

String defaultOngoingTitle(String clientName) {
  final name = clientName.trim();
  return name.isEmpty ? 'Ongoing support' : '$name support';
}

String jobListSubtitle({
  required String kind,
  required String status,
  required bool hasSite,
  required bool hasBranch,
}) {
  final where = hasSite
      ? locationModeLabel('site')
      : hasBranch
          ? locationModeLabel('branch')
          : 'Location not set';
  return '${kindLabel(kind)} · ${jobStatusLabel(status)} · $where';
}
