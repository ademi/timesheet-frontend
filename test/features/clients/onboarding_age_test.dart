import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/utils/onboarding_age.dart';

void main() {
  test('isUnder18 true day before 18th birthday', () {
    final dob = DateTime(2008, 8, 27);
    final today = DateTime(2026, 8, 26);
    expect(isUnder18(dob, today: today), isTrue);
  });

  test('isUnder18 false on 18th birthday', () {
    final dob = DateTime(2008, 8, 26);
    final today = DateTime(2026, 8, 26);
    expect(isUnder18(dob, today: today), isFalse);
  });
}
