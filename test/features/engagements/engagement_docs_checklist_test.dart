import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/widgets/engagement_docs_checklist.dart';

void main() {
  final now = DateTime.utc(2026, 7, 31);

  EngagementOut engagement({String status = 'pending_docs'}) => EngagementOut(
    id: 'eng-1',
    tenantId: 'tenant-1',
    tenantName: 'Acme Care',
    contractorId: 'contractor-1',
    status: status,
    createdAt: now,
    updatedAt: now,
    requiredDocCategories: const [
      RequiredDocCategory(category: 'wwcc', isRequired: true),
      RequiredDocCategory(category: 'cpr', isRequired: true),
    ],
  );

  CredentialOut credential(String type) => CredentialOut(
    id: 'cred-$type',
    contractorId: 'contractor-1',
    credentialType: type,
    status: 'active',
    provenanceState: 'self_reported',
    evidencePresence: 'present',
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('shows required, have, and missing document categories', (
    tester,
  ) async {
    List<String>? requestedMissingCategories;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngagementDocsChecklist(
            engagement: engagement(),
            credentials: [credential('wwcc')],
            onAddMissing:
                (categories) => requestedMissingCategories = categories,
          ),
        ),
      ),
    );

    expect(find.text('Acme Care'), findsOneWidget);
    expect(find.textContaining('Required', findRichText: true), findsOneWidget);
    expect(find.textContaining('wwcc', findRichText: true), findsNWidgets(2));
    expect(find.textContaining('cpr', findRichText: true), findsNWidgets(2));
    expect(find.textContaining('Have', findRichText: true), findsOneWidget);
    expect(find.textContaining('Missing', findRichText: true), findsOneWidget);
    expect(find.text('Add missing credential'), findsOneWidget);
    await tester.tap(find.text('Add missing credential'));
    expect(requestedMissingCategories, ['cpr']);
  });

  testWidgets('reports each accepted engagement status with a chip', (
    tester,
  ) async {
    for (final status in ['pending_docs', 'approved', 'active']) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EngagementStatusChip(status: status))),
      );

      expect(find.text(status.replaceAll('_', ' ')), findsOneWidget);
    }
  });
}
