import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Resolves UTC offset for an IANA zone at [utc]. Tests may inject fixed offsets.
@visibleForTesting
Duration Function(String tenantTimezone, DateTime utc)? tenantUtcOffsetOverride;

bool _timezoneDatabaseInitialized = false;

/// Loads IANA zone data once (safe to call repeatedly).
void ensureTimezoneDatabaseInitialized() {
  if (_timezoneDatabaseInitialized) return;
  tz_data.initializeTimeZones();
  _timezoneDatabaseInitialized = true;
}

tz.Location? _locationFor(String tenantTimezone) {
  ensureTimezoneDatabaseInitialized();
  try {
    return tz.getLocation(tenantTimezone);
  } catch (_) {
    return null;
  }
}

/// True when [tenantTimezone] is applied for civil calendar math (IANA or test override).
bool isTenantTimezoneConversionApplied(String? tenantTimezone) {
  final tzId = tenantTimezone?.trim();
  if (tzId == null || tzId.isEmpty) return false;
  if (tenantUtcOffsetOverride != null) return true;
  return _locationFor(tzId) != null;
}

DateTime _civilFromShiftedUtc(DateTime shifted) {
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
    shifted.microsecond,
  );
}

DateTime _civilFromTzDateTime(tz.TZDateTime civil) {
  return DateTime(
    civil.year,
    civil.month,
    civil.day,
    civil.hour,
    civil.minute,
    civil.second,
    civil.millisecond,
    civil.microsecond,
  );
}

/// Tenant civil instant for calendar math (week boundaries, day chips).
DateTime tenantCivilFromUtc(DateTime utc, String? tenantTimezone) {
  final utcInstant = utc.toUtc();
  final tzId = tenantTimezone?.trim();
  if (tzId == null || tzId.isEmpty) {
    return utcInstant.toLocal();
  }
  final override = tenantUtcOffsetOverride;
  if (override != null) {
    return _civilFromShiftedUtc(utcInstant.add(override(tzId, utcInstant)));
  }
  final location = _locationFor(tzId);
  if (location == null) {
    return utcInstant.toLocal();
  }
  return _civilFromTzDateTime(tz.TZDateTime.from(utcInstant, location));
}

/// UTC instant for 00:00 on the tenant civil calendar date [civilDate].
DateTime tenantCivilDateStartUtc(DateTime civilDate, String? tenantTimezone) {
  final d = DateTime(civilDate.year, civilDate.month, civilDate.day);
  final tzId = tenantTimezone?.trim();
  if (tzId == null || tzId.isEmpty) {
    return d.toUtc();
  }
  final override = tenantUtcOffsetOverride;
  if (override != null) {
    final ref = DateTime.utc(d.year, d.month, d.day);
    return ref.subtract(override(tzId, ref));
  }
  final location = _locationFor(tzId);
  if (location == null) {
    return d.toUtc();
  }
  return tz.TZDateTime(location, d.year, d.month, d.day).toUtc();
}

/// UTC instant for a tenant civil wall-clock [civil] (date + time of day).
DateTime tenantCivilInstantUtc(DateTime civil, String? tenantTimezone) {
  final tzId = tenantTimezone?.trim();
  if (tzId == null || tzId.isEmpty) {
    return civil.toUtc();
  }
  final override = tenantUtcOffsetOverride;
  if (override != null) {
    final ref = DateTime.utc(
      civil.year,
      civil.month,
      civil.day,
      civil.hour,
      civil.minute,
      civil.second,
      civil.millisecond,
      civil.microsecond,
    );
    return ref.subtract(override(tzId, ref));
  }
  final location = _locationFor(tzId);
  if (location == null) {
    return civil.toUtc();
  }
  return tz.TZDateTime(
    location,
    civil.year,
    civil.month,
    civil.day,
    civil.hour,
    civil.minute,
    civil.second,
    civil.millisecond,
    civil.microsecond,
  ).toUtc();
}

/// UTC instant for 00:00 on the tenant civil day containing [utc].
DateTime startOfTenantCivilDayUtc(DateTime utc, String? tenantTimezone) {
  final civil = tenantCivilFromUtc(utc, tenantTimezone);
  return tenantCivilDateStartUtc(
    DateTime(civil.year, civil.month, civil.day),
    tenantTimezone,
  );
}

/// Rolling horizon `[startOfToday, startOfToday + [days])` as UTC instants.
({DateTime from, DateTime to}) tenantHorizonWindowUtc(
  DateTime utcNow,
  String? tenantTimezone, {
  int days = 14,
}) {
  final from = startOfTenantCivilDayUtc(utcNow, tenantTimezone);
  final civil = tenantCivilFromUtc(utcNow, tenantTimezone);
  final endCivil = DateTime(civil.year, civil.month, civil.day).add(
    Duration(days: days),
  );
  return (from: from, to: tenantCivilDateStartUtc(endCivil, tenantTimezone));
}

/// Horizon fill from a tenant civil calendar date (split-recurrence paths).
({DateTime from, DateTime to}) tenantHorizonWindowFromCivilDate(
  DateTime civilDate,
  String? tenantTimezone, {
  int days = 14,
}) {
  final d = DateTime(civilDate.year, civilDate.month, civilDate.day);
  return (
    from: tenantCivilDateStartUtc(d, tenantTimezone),
    to: tenantCivilDateStartUtc(d.add(Duration(days: days)), tenantTimezone),
  );
}

/// Monday 00:00 (civil) of the week containing [utc] in tenant/local civil time.
DateTime startOfTenantWeekMonday(DateTime utc, String? tenantTimezone) {
  final civil = tenantCivilFromUtc(utc, tenantTimezone);
  final day = DateTime(civil.year, civil.month, civil.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}
