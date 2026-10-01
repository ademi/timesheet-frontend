import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/travel_item_rules.dart';

void main() {
  test('accepts 799 and activity transport mids', () {
    expect(isTravelClaimableItemNumber('01_799_0107_1_1'), isTrue);
    expect(isTravelClaimableItemNumber('04_590_0125_6_1'), isTrue);
    expect(isTravelClaimableItemNumber('04_591_0136_6_1'), isTrue);
    expect(isTravelClaimableItemNumber('07_501_0106_6_3'), isTrue);
    expect(isTravelClaimableItemNumber('04_821_0133_6_1'), isTrue);
    expect(isTravelClaimableItemNumber('04_592_0125_6_1'), isTrue);
  });

  test('rejects hourly self care and unknown mids', () {
    expect(isTravelClaimableItemNumber('01_011_0107_1_1'), isFalse);
    expect(isTravelClaimableItemNumber('02_051_0108_1_1'), isFalse);
    expect(isTravelClaimableItemNumber(null), isFalse);
    expect(isTravelClaimableItemNumber('bad'), isFalse);
  });

  test('registration group parse and anchor match', () {
    expect(registrationGroupFromItemNumber('01_799_0107_1_1'), '0107');
    expect(registrationGroupFromItemNumber('bad'), isNull);
    expect(
      travelCodeMatchesAnchors(
        travelCode: '01_799_0107_1_1',
        anchorCodes: const ['01_011_0107_1_1'],
      ),
      isTrue,
    );
    expect(
      travelCodeMatchesAnchors(
        travelCode: '01_799_0107_1_1',
        anchorCodes: const ['04_104_0125_6_1'],
      ),
      isFalse,
    );
  });

  test('empty anchors match any travel code', () {
    expect(
      travelCodeMatchesAnchors(
        travelCode: '01_799_0107_1_1',
        anchorCodes: const [],
      ),
      isTrue,
    );
  });

  test('uniqueRegistrationGroups collects distinct reg groups', () {
    expect(
      uniqueRegistrationGroups(const [
        '01_011_0107_1_1',
        '01_799_0107_1_1',
        '04_104_0125_6_1',
        'bad',
      ]),
      {'0107', '0125'},
    );
  });

  test('units constant is E only and mid allowlist includes 799', () {
    expect(travelClaimUnits, {'E'});
    expect(travelClaimMidSegments.contains('799'), isTrue);
  });

  test('mmmTravelCapMinutes by category', () {
    expect(mmmTravelCapMinutes(1), 30);
    expect(mmmTravelCapMinutes(2), 30);
    expect(mmmTravelCapMinutes(3), 30);
    expect(mmmTravelCapMinutes(4), 60);
    expect(mmmTravelCapMinutes(5), 60);
    expect(mmmTravelCapMinutes(6), isNull);
    expect(mmmTravelCapMinutes(7), isNull);
    expect(mmmTravelCapMinutes(null), isNull);
    expect(mmmTravelCapMinutes(0), isNull);
  });

  test('isOverMmmCap soft warn only when over', () {
    expect(isOverMmmCap(30, 1), isFalse);
    expect(isOverMmmCap(31, 1), isTrue);
    expect(isOverMmmCap(60, 4), isFalse);
    expect(isOverMmmCap(61, 5), isTrue);
    expect(isOverMmmCap(120, 6), isFalse);
    expect(isOverMmmCap(120, null), isFalse);
  });

  test('minutesToHours quantizes to 4dp', () {
    expect(minutesToHours(60), 1.0);
    expect(minutesToHours(30), 0.5);
    expect(minutesToHours(45), 0.75);
    expect(minutesToHours(1), 0.0167);
  });

  test('hoursToMinutes round-trips minutesToHours', () {
    expect(hoursToMinutes(1), 60);
    expect(hoursToMinutes(0.75), 45);
    expect(hoursToMinutes(minutesToHours(45)), 45);
  });

  test('therapy half-rate registration groups', () {
    expect(isTherapyHalfRate('0128'), isTrue);
    expect(isTherapyHalfRate('0107'), isFalse);
    expect(isTherapyHalfRate(null), isFalse);
    expect(
      anyTherapyHalfRateItem(const ['15_001_0128_1_3', '01_011_0107_1_1']),
      isTrue,
    );
    expect(anyTherapyHalfRateItem(const ['01_011_0107_1_1']), isFalse);
  });
}
