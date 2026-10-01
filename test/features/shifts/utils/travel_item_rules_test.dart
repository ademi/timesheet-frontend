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
}
