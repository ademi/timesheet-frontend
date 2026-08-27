import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/shared/widgets/floating_error_notice.dart';

void main() {
  testWidgets('FloatingErrorNotice shows message and dismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingErrorNotice(
            message: 'NDIS number is required.',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('NDIS number is required.'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('dismiss tap animates out then calls onDismiss', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingErrorNotice(
            message: 'Something went wrong.',
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, isFalse);

    await tester.pumpAndSettle();
    expect(dismissed, isTrue);
  });

  testWidgets('clamps message to three lines with ellipsis', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingErrorNotice(
            message: 'one\ntwo\nthree\nfour\nfive',
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.text('one\ntwo\nthree\nfour\nfive'));
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('uses error tokens, radius 8, and live region', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FloatingErrorNotice(
            message: 'NDIS number is required.',
            onDismiss: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(FloatingErrorNotice),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.errorBackground);
    expect(decoration.borderRadius, BorderRadius.circular(8));

    final node = tester.getSemantics(find.text('NDIS number is required.'));
    expect(node.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
    handle.dispose();
  });
}
