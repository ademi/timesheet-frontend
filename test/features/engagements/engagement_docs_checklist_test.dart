import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/widgets/engagement_docs_checklist.dart';

void main() {
  final now = DateTime.utc(2026, 7, 31);

  EngagementOut engagement({
    String status = 'pending_docs',
    Map<String, bool?> flags = const {},
    List<String> requiredResolved = const [
      'resume',
      'passport_id',
      'wwcc',
    ],
    List<String>? apiMissing,
    int? photoIdPointsTotal,
  }) => EngagementOut(
    id: 'eng-1',
    tenantId: 'tenant-1',
    tenantName: 'Acme Care',
    contractorId: 'contractor-1',
    status: status,
    createdAt: now,
    updatedAt: now,
    documentPack: 'support_worker_v1',
    requiredResolved: requiredResolved,
    apiMissing: apiMissing,
    photoIdPointsTotal: photoIdPointsTotal,
    onboardingFlags: flags,
    requiredDocCategories: const [
      RequiredDocCategory(category: 'wwcc', isRequired: true),
      RequiredDocCategory(category: 'cpr', isRequired: true),
    ],
  );

  CredentialOut credential(String type, {int? idPoints}) => CredentialOut(
    id: 'cred-$type',
    contractorId: 'contractor-1',
    credentialType: type,
    status: 'active',
    provenanceState: 'self_reported',
    evidencePresence: 'present',
    idPoints: idPoints,
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('shows Always / Conditional / Optional sections', (tester) async {
    List<String>? requestedMissingCategories;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngagementDocsChecklist(
            engagement: engagement(
              flags: const {
                'wwcc_applicable': true,
                'qualifications_applicable': false,
                'drives_participants': false,
                'uses_own_vehicle': false,
              },
              apiMissing: const ['passport_id', 'wwcc'],
              photoIdPointsTotal: 70,
            ),
            credentials: [credential('passport_id', idPoints: 70)],
            onAddMissing:
                (categories) => requestedMissingCategories = categories,
          ),
        ),
      ),
    );

    expect(find.text('Acme Care'), findsOneWidget);
    expect(find.text('Always required'), findsOneWidget);
    expect(find.text('Conditional'), findsOneWidget);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.textContaining('Photo ID points: 70 / 100'), findsOneWidget);
    expect(find.text('Add missing credential'), findsOneWidget);
    await tester.tap(find.text('Add missing credential'));
    expect(requestedMissingCategories, containsAll(['passport_id', 'wwcc']));
  });

  testWidgets('locks conditionals until flags answered', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngagementDocsChecklist(
            engagement: engagement(flags: const {}),
            credentials: const [],
          ),
        ),
      ),
    );

    expect(find.textContaining('answer on Profile to unlock'), findsWidgets);
  });

  testWidgets('reports each accepted engagement status with a chip', (
    tester,
  ) async {
    for (final status in ['pending_docs', 'approved', 'active']) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: EngagementStatusChip(status: status))),
      );

      expect(find.text(engagementStatusLabel(status)), findsOneWidget);
    }
  });
}
