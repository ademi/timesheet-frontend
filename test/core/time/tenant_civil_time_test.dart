import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/time/tenant_civil_time.dart';

void main() {
  setUp(() {
    tenantUtcOffsetOverride = null;
    ensureTimezoneDatabaseInitialized();
  });

  tearDown(() {
    tenantUtcOffsetOverride = null;
  });

  group('tenantCivilFromUtc', () {
    test('uses device local when tenant timezone is empty', () {
      final utc = DateTime.utc(2026, 8, 10, 12);
      final civil = tenantCivilFromUtc(utc, null);
      expect(civil, utc.toLocal());
    });

    test('uses IANA zone when available', () {
      final utc = DateTime.utc(2026, 8, 9, 14); // 00:00 Sydney (+10, no DST Aug)
      final civil = tenantCivilFromUtc(utc, 'Australia/Sydney');
      expect(civil.year, 2026);
      expect(civil.month, 8);
      expect(civil.day, 10);
      expect(civil.hour, 0);
    });

    test('honours test override for fixed offsets', () {
      tenantUtcOffsetOverride = (_, __) => const Duration(hours: 10);
      final civil = tenantCivilFromUtc(
        DateTime.utc(2026, 8, 9, 16),
        'Australia/Sydney',
      );
      expect(civil.day, 10);
      expect(civil.hour, 2);
    });
  });

  group('tenantHorizonWindowUtc', () {
    test('returns fourteen-day tenant-civil window in UTC', () {
      tenantUtcOffsetOverride = (_, __) => const Duration(hours: 10);
      final window = tenantHorizonWindowUtc(
        DateTime.utc(2026, 8, 9, 16),
        'Australia/Sydney',
      );
      expect(window.to.difference(window.from), const Duration(days: 14));
      expect(window.from, DateTime.utc(2026, 8, 9, 14));
      expect(window.to, DateTime.utc(2026, 8, 23, 14));
    });

    test('uses Sydney midnight boundaries via IANA data', () {
      final window = tenantHorizonWindowUtc(
        DateTime.utc(2026, 8, 9, 14, 30),
        'Australia/Sydney',
      );
      expect(window.from, DateTime.utc(2026, 8, 9, 14));
      expect(window.to, DateTime.utc(2026, 8, 23, 14));
    });
  });

  group('startOfTenantWeekMonday', () {
    test('aligns to tenant civil Monday across midnight UTC', () {
      tenantUtcOffsetOverride = (tz, _) {
        if (tz == 'Australia/Sydney') return const Duration(hours: 10);
        return Duration.zero;
      };
      final monday = startOfTenantWeekMonday(
        DateTime.utc(2026, 8, 9, 16),
        'Australia/Sydney',
      );
      expect(monday.weekday, DateTime.monday);
      expect(monday.day, 10);
    });
  });

  group('isTenantTimezoneConversionApplied', () {
    test('is true for valid IANA zone', () {
      expect(isTenantTimezoneConversionApplied('Australia/Sydney'), isTrue);
    });

    test('is false for empty timezone', () {
      expect(isTenantTimezoneConversionApplied(''), isFalse);
      expect(isTenantTimezoneConversionApplied(null), isFalse);
    });
  });
}
