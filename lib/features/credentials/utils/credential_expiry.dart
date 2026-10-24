/// Days until [expiresOn] (date-only, local). Negative = already expired.
int? daysUntilExpiry(DateTime? expiresOn, {DateTime? now}) {
  if (expiresOn == null) return null;
  final today = now ?? DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final end = DateTime(expiresOn.year, expiresOn.month, expiresOn.day);
  return end.difference(start).inDays;
}

/// Short label for list/detail chips. Null when no date or far from expiry.
String? credentialExpiryLabel(DateTime? expiresOn, {DateTime? now}) {
  final days = daysUntilExpiry(expiresOn, now: now);
  if (days == null) return null;
  if (days < 0) {
    final ago = -days;
    return ago == 1 ? 'Expired yesterday' : 'Expired $ago days ago';
  }
  if (days == 0) return 'Expires today';
  if (days == 1) return 'Expires tomorrow';
  if (days <= 90) return 'Expires in $days days';
  return null;
}

enum CredentialExpiryUrgency { none, watch, soon, critical, expired }

CredentialExpiryUrgency credentialExpiryUrgency(
  DateTime? expiresOn, {
  DateTime? now,
}) {
  final days = daysUntilExpiry(expiresOn, now: now);
  if (days == null) return CredentialExpiryUrgency.none;
  if (days < 0) return CredentialExpiryUrgency.expired;
  if (days <= 7) return CredentialExpiryUrgency.critical;
  if (days <= 30) return CredentialExpiryUrgency.soon;
  if (days <= 90) return CredentialExpiryUrgency.watch;
  return CredentialExpiryUrgency.none;
}

bool isCredentialExpiringSoon(DateTime? expiresOn, {DateTime? now}) {
  final u = credentialExpiryUrgency(expiresOn, now: now);
  return u == CredentialExpiryUrgency.critical ||
      u == CredentialExpiryUrgency.soon ||
      u == CredentialExpiryUrgency.expired;
}
