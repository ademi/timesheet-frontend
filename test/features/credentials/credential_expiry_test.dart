import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/utils/credential_expiry.dart';

void main() {
  final now = DateTime(2026, 10, 24);

  group('daysUntilExpiry', () {
    test('null when no date', () {
      expect(daysUntilExpiry(null, now: now), isNull);
    });

    test('counts calendar days', () {
      expect(daysUntilExpiry(DateTime(2026, 10, 31), now: now), 7);
      expect(daysUntilExpiry(DateTime(2026, 10, 24), now: now), 0);
      expect(daysUntilExpiry(DateTime(2026, 10, 20), now: now), -4);
    });
  });

  group('credentialExpiryLabel', () {
    test('formats near and expired', () {
      expect(
        credentialExpiryLabel(DateTime(2026, 10, 24), now: now),
        'Expires today',
      );
      expect(
        credentialExpiryLabel(DateTime(2026, 10, 25), now: now),
        'Expires tomorrow',
      );
      expect(
        credentialExpiryLabel(DateTime(2026, 11, 3), now: now),
        'Expires in 10 days',
      );
      expect(
        credentialExpiryLabel(DateTime(2026, 10, 23), now: now),
        'Expired yesterday',
      );
    });

    test('null when beyond 90 days', () {
      expect(
        credentialExpiryLabel(DateTime(2027, 2, 1), now: now),
        isNull,
      );
    });
  });

  group('isCredentialExpiringSoon', () {
    test('true within 30 days or expired', () {
      expect(
        isCredentialExpiringSoon(DateTime(2026, 11, 20), now: now),
        isTrue,
      );
      expect(
        isCredentialExpiringSoon(DateTime(2026, 10, 1), now: now),
        isTrue,
      );
      expect(
        isCredentialExpiringSoon(DateTime(2027, 1, 1), now: now),
        isFalse,
      );
    });
  });
}
