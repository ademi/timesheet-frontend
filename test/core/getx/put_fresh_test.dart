import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/core/getx/put_fresh.dart';

class _ProbeController extends GetxController {
  _ProbeController(this.label);
  final String label;
  var reenterCount = 0;
}

void main() {
  setUp(Get.reset);
  tearDown(Get.reset);

  test('putFresh replaces prior instance', () {
    final first = putFresh(() => _ProbeController('a'));
    final second = putFresh(() => _ProbeController('b'));

    expect(identical(first, second), isFalse);
    expect(Get.find<_ProbeController>().label, 'b');
    expect(Get.isRegistered<_ProbeController>(), isTrue);
  });

  test('Get.put without delete keeps the prior instance (regression guard)', () {
    final first = Get.put(_ProbeController('a'));
    final reused = Get.put(_ProbeController('b'));

    expect(identical(first, reused), isTrue);
    expect(reused.label, 'a');
  });

  test('putOrReenter reuses instance and invokes onReenter', () {
    final first = putOrReenter(() => _ProbeController('a'));
    final second = putOrReenter(
      () => _ProbeController('b'),
      onReenter: (c) => c.reenterCount++,
    );

    expect(identical(first, second), isTrue);
    expect(second.label, 'a');
    expect(second.reenterCount, 1);
  });

  test('putOrReenter permanent keeps instance across SmartManagement', () {
    putOrReenter(() => _ProbeController('a'), permanent: true);
    expect(Get.isRegistered<_ProbeController>(), isTrue);
    expect(Get.find<_ProbeController>().label, 'a');
  });
}
