import 'package:flutter/foundation.dart';

/// Resolves UTC offset for an IANA zone at [utc]. Production leaves this null
/// until a timezone package is added; tests may inject fixed offsets.
@visibleForTesting
Duration Function(String tenantTimezone, DateTime utc)? tenantUtcOffsetOverride;

/// True when [tenantTimezone] is applied for civil calendar math (IANA or test override).
bool isTenantTimezoneConversionApplied(String? tenantTimezone) {
  final tz = tenantTimezone?.trim();
  if (tz == null || tz.isEmpty) return false;
  return tenantUtcOffsetOverride != null;
}

/// Tenant civil instant for calendar math (week boundaries, day chips).
///
/// Without an IANA package in pubspec, non-empty [tenantTimezone] is honoured
/// only when [tenantUtcOffsetOverride] is set (tests). Otherwise falls back to
/// device local — same copy as jobs recurrence form.
DateTime tenantCivilFromUtc(DateTime utc, String? tenantTimezone) {
  final tz = tenantTimezone?.trim();
  if (tz == null || tz.isEmpty) {
    return utc.toLocal();
  }
  final override = tenantUtcOffsetOverride;
  if (override != null) {
    return utc.add(override(tz, utc));
  }
  // Full IANA resolution awaits a timezone package; device local for now.
  return utc.toLocal();
}

/// Monday 00:00 (civil) of the week containing [utc] in tenant/local civil time.
DateTime startOfTenantWeekMonday(DateTime utc, String? tenantTimezone) {
  final civil = tenantCivilFromUtc(utc, tenantTimezone);
  final day = DateTime(civil.year, civil.month, civil.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
