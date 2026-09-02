import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/engagements/widgets/invite_sent_dialog.dart';

void main() {
  testWidgets('InviteSentDialog shows success copy without copy link', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InviteSentDialog(expiresAt: DateTime.utc(2026, 12, 1, 10)),
        ),
      ),
    );

    expect(find.text('Invite sent'), findsOneWidget);
    expect(
      find.textContaining('They can register using the link in that email'),
      findsOneWidget,
    );
    expect(find.text('Copy link'), findsNothing);
    expect(find.textContaining('copy and share'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
  });
}
