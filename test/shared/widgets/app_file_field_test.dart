import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/app_file_field.dart';

void main() {
  testWidgets('shows label and empty hint', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'NDIS plan PDF',
            fileName: null,
            onPick: () {},
          ),
        ),
      ),
    );
    expect(find.text('NDIS plan PDF'), findsOneWidget);
    expect(find.text('No file'), findsOneWidget);
  });

  testWidgets('shows file name and clear when present', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'Consent',
            fileName: 'consent.pdf',
            onPick: () {},
            onClear: () => cleared = true,
          ),
        ),
      ),
    );
    expect(find.text('consent.pdf'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    expect(cleared, isTrue);
  });

  testWidgets('invokes onPick when Choose tapped', (tester) async {
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'Upload',
            fileName: null,
            onPick: () => picked = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    expect(picked, isTrue);
  });

  testWidgets('ellipsizes long file names', (tester) async {
    const longName =
        'very-long-consent-document-name-that-should-not-wrap.pdf';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: AppFileField(
              label: 'Consent',
              fileName: longName,
              onPick: () {},
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('disabled Choose does not invoke onPick', (tester) async {
    var picked = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'Upload',
            fileName: null,
            enabled: false,
            onPick: () => picked = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose file'));
    expect(picked, isFalse);
  });

  testWidgets('omits clear when onClear is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppFileField(
            label: 'Consent',
            fileName: 'consent.pdf',
            onPick: () {},
          ),
        ),
      ),
    );
    expect(find.byTooltip('Clear'), findsNothing);
  });
}
