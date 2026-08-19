import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/core/responsive/equal_fill_row.dart';

void main() {
  testWidgets('two children split 50/50', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: EqualFillRow(
              children: [
                SizedBox(key: Key('a'), height: 10),
                SizedBox(key: Key('b'), height: 10),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('a'))).width, 196);
    expect(tester.getSize(find.byKey(const Key('b'))).width, 196);
  });

  testWidgets('single child uses full width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 200));
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: EqualFillRow(
              children: [SizedBox(key: Key('only'), height: 10)],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const Key('only'))).width, 400);
  });

  testWidgets('empty children render nothing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: EqualFillRow(children: []),
      ),
    );
    expect(find.byType(Row), findsNothing);
  });
}
