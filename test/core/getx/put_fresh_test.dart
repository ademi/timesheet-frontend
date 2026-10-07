import 'package:flutter/widgets.dart';
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

  testWidgets('putOrReenter reuses instance and defers onReenter', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());

    final first = putOrReenter(() => _ProbeController('a'));
    final second = putOrReenter(
      () => _ProbeController('b'),
      onReenter: (c) => c.reenterCount++,
    );

    expect(identical(first, second), isTrue);
    expect(second.label, 'a');
    // Must not run during the GoRouter builder phase.
    expect(second.reenterCount, 0);

    tester.binding.scheduleFrame();
    await tester.pump();
    expect(second.reenterCount, 1);
  });

  testWidgets('putOrReenter skips deferred onReenter if instance replaced', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());

    putOrReenter(() => _ProbeController('a'));
    putOrReenter(
      () => _ProbeController('b'),
      onReenter: (c) => c.reenterCount++,
    );
    putFresh(() => _ProbeController('c'));

    tester.binding.scheduleFrame();
    await tester.pump();
    expect(Get.find<_ProbeController>().label, 'c');
    expect(Get.find<_ProbeController>().reenterCount, 0);
  });

  test('putOrReenter permanent keeps instance across SmartManagement', () {
    putOrReenter(() => _ProbeController('a'), permanent: true);
    expect(Get.isRegistered<_ProbeController>(), isTrue);
    expect(Get.find<_ProbeController>().label, 'a');
  });
}
