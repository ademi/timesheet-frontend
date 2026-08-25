import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/widgets/client_detail_support_section.dart';

void main() {
  testWidgets('shows Start ongoing when no standing job', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailSupportSection(
        hasOngoing: false,
        canManage: true,
        supportItemCode: null,
        supportItemName: null,
        onStartOngoing: () {},
        onBookOne: () {},
        onOpenOngoing: () {},
      ),
    ));
    expect(find.text('Start ongoing support'), findsOneWidget);
    expect(find.text('Book one session'), findsOneWidget);
  });

  testWidgets('book one session enabled when ongoing exists', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailSupportSection(
        hasOngoing: true,
        canManage: true,
        supportItemCode: null,
        supportItemName: null,
        onStartOngoing: () {},
        onBookOne: () {},
        onOpenOngoing: () {},
      ),
    ));
    expect(find.text('Book one session'), findsOneWidget);
    expect(find.text('Start ongoing support'), findsNothing);
    expect(find.text('Open support'), findsOneWidget);
  });

  testWidgets('book one available without standing job (D9 auto-ensure)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailSupportSection(
        hasOngoing: false,
        canManage: true,
        supportItemCode: null,
        supportItemName: null,
        onStartOngoing: () {},
        onBookOne: () {},
        onOpenOngoing: () {},
      ),
    ));
    expect(find.text('Book one session'), findsOneWidget);
    expect(find.text('Start ongoing support first.'), findsNothing);
  });

  testWidgets('support section copy never says XOR standing or Generate',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailSupportSection(
        hasOngoing: false,
        canManage: true,
        supportItemCode: null,
        supportItemName: null,
        onStartOngoing: () {},
        onBookOne: () {},
        onOpenOngoing: () {},
      ),
    ));
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    expect(texts, isNot(contains('xor')));
    expect(texts, isNot(contains('standing')));
    expect(texts, isNot(contains('generate')));
  });

  testWidgets('Start ongoing tap calls onStartOngoing', (tester) async {
    var started = false;
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailSupportSection(
        hasOngoing: false,
        canManage: true,
        supportItemCode: null,
        supportItemName: null,
        onStartOngoing: () => started = true,
        onBookOne: () {},
        onOpenOngoing: () {},
      ),
    ));
    await tester.tap(find.text('Start ongoing support'));
    expect(started, isTrue);
  });

  testWidgets('Book one and Open support taps call callbacks', (tester) async {
    var booked = false;
    var opened = false;
    await tester.pumpWidget(MaterialApp(
      home: ClientDetailSupportSection(
        hasOngoing: true,
        canManage: true,
        supportItemCode: null,
        supportItemName: null,
        onStartOngoing: () {},
        onBookOne: () => booked = true,
        onOpenOngoing: () => opened = true,
      ),
    ));
    await tester.tap(find.text('Book one session'));
    await tester.tap(find.text('Open support'));
    expect(booked, isTrue);
    expect(opened, isTrue);
  });

  testWidgets('client detail shows standing support item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientDetailSupportSection(
          hasOngoing: true,
          canManage: true,
          supportItemCode: '01_011_0107_1_1',
          supportItemName: 'Self care',
          onStartOngoing: () {},
          onBookOne: () {},
          onOpenOngoing: () {},
        ),
      ),
    );
    expect(find.textContaining('Self care'), findsOneWidget);
    expect(find.textContaining('01_011_0107_1_1'), findsOneWidget);
  });

  testWidgets('omits support item line when code or name missing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClientDetailSupportSection(
          hasOngoing: true,
          canManage: true,
          supportItemCode: '01_011_0107_1_1',
          supportItemName: null,
          onStartOngoing: () {},
          onBookOne: () {},
          onOpenOngoing: () {},
        ),
      ),
    );
    expect(find.textContaining('01_011_0107_1_1'), findsNothing);
  });
}
