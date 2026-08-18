import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/utils/name_sort.dart';

void main() {
  test('sortedByName is case-insensitive and trims whitespace', () {
    final sorted = sortedByName(
      ['  zoe', 'Ali', 'ben'],
      (name) => name,
    );
    expect(sorted, ['Ali', 'ben', '  zoe']);
  });

  test('compareNames treats null as empty', () {
    expect(compareNames(null, 'a'), lessThan(0));
    expect(compareNames('a', null), greaterThan(0));
    expect(compareNames(null, null), 0);
  });
}
