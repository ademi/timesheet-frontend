import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/required_slots_input.dart';

void main() {
  test('parseRequiredSlots keeps digits only and clamps min 1', () {
    expect(parseRequiredSlots(''), 1);
    expect(parseRequiredSlots('0'), 1);
    expect(parseRequiredSlots('3'), 3);
    expect(parseRequiredSlots('12a'), 12);
    expect(parseRequiredSlots('99'), 20); // soft UI max
  });
}
