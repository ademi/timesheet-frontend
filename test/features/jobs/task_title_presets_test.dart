import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/task_title_presets.dart';

void main() {
  test('parseTaskTitles trims and drops blank lines', () {
    expect(
      parseTaskTitles('Personal care\n  \nTransport\n'),
      ['Personal care', 'Transport'],
    );
  });

  test('appendTaskTitleLine adds newline-separated titles', () {
    expect(appendTaskTitleLine('', 'Personal care'), 'Personal care');
    expect(
      appendTaskTitleLine('Personal care', 'Transport'),
      'Personal care\nTransport',
    );
    expect(appendTaskTitleLine('Existing', '  '), 'Existing');
  });
}
