import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/utils/email_utils.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/widgets/pending_invite_contact_dialog.dart';

void main() {
  group('EmailUtils', () {
    test('normalizes and validates common addresses', () {
      expect(EmailUtils.normalize('  User@Example.com '), 'user@example.com');
      expect(EmailUtils.isValid('user@example.com'), isTrue);
      expect(EmailUtils.isValid('not-an-email'), isFalse);
      expect(EmailUtils.validationError('bad'), EmailUtils.formatHint);
      expect(EmailUtils.validationError(''), EmailUtils.formatHint);
      expect(EmailUtils.validationError(null, required: false), isNull);
    });
  });

  testWidgets('PendingInviteContactDialog rejects invalid email', (tester) async {
    final invite = ContractorRegistrationInviteOut(
      id: 'invite-1',
      email: 'contractor@example.com',
      phone: '+61400111222',
      requiredCategories: const ['ndis_worker_screening'],
      expiresAt: DateTime.utc(2026, 12, 1),
      createdAt: DateTime.utc(2026, 11, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PendingInviteContactDialog(invite: invite)),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text(EmailUtils.formatHint), findsOneWidget);
  });
}
