import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/subject_tab_bar.dart';

void main() {
  testWidgets('selecting a chip reports the index', (tester) async {
    var index = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubjectTabBar(
            labels: const ['Overview', 'Credentials'],
            index: index,
            keyPrefix: 'contractor-detail-tab',
            onChanged: (i) => index = i,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('contractor-detail-tab-0')), findsOneWidget);
    await tester.tap(find.text('Credentials'));
    await tester.pump();
    expect(index, 1);
  });
}
