import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/routes/app_navigation.dart';

class _SampleResult {
  const _SampleResult(this.id);
  final String id;
}

void main() {
  group('readBoolResult', () {
    test('returns true only for literal true', () {
      expect(readBoolResult(true), isTrue);
      expect(readBoolResult(false), isFalse);
      expect(readBoolResult(null), isFalse);
      expect(readBoolResult(1), isFalse);
    });
  });

  group('readTypedResult', () {
    test('returns value when type matches', () {
      const sample = _SampleResult('e1');
      expect(readTypedResult<_SampleResult>(sample), sample);
    });

    test('returns null when type does not match', () {
      expect(readTypedResult<_SampleResult>('wrong'), isNull);
    });
  });
}
