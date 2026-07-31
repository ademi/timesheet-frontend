import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/utils/missing_categories.dart';

void main() {
  final now = DateTime.utc(2026, 7, 31);

  EngagementOut engagement(List<String> categories) => EngagementOut(
    id: 'eng-1',
    tenantId: 'tenant-1',
    contractorId: 'contractor-1',
    status: 'pending_docs',
    createdAt: now,
    updatedAt: now,
    requiredDocCategories: categories
        .map((c) => RequiredDocCategory(category: c, isRequired: true))
        .toList(growable: false),
  );

  CredentialOut credential({
    required String type,
    String evidencePresence = 'present',
  }) => CredentialOut(
    id: 'cred-$type',
    contractorId: 'contractor-1',
    credentialType: type,
    status: 'active',
    provenanceState: 'self_reported',
    evidencePresence: evidencePresence,
    createdAt: now,
    updatedAt: now,
  );

  test('returns all required categories when no credentials', () {
    final missing = missingCategories(
      engagement(['wwcc', 'police_check']),
      const [],
    );

    expect(missing, {'wwcc', 'police_check'});
  });

  test('excludes categories with present evidence', () {
    final missing = missingCategories(
      engagement(['wwcc', 'police_check']),
      [
        credential(type: 'wwcc'),
      ],
    );

    expect(missing, {'police_check'});
  });

  test('treats none, absent, and quarantined as missing evidence', () {
    for (final presence in ['none', 'absent', 'quarantined']) {
      final missing = missingCategories(
        engagement(['wwcc']),
        [credential(type: 'wwcc', evidencePresence: presence)],
      );

      expect(missing, {'wwcc'}, reason: presence);
    }
  });

  test('ignores non-required doc categories', () {
    final e = EngagementOut(
      id: 'eng-1',
      tenantId: 'tenant-1',
      contractorId: 'contractor-1',
      status: 'pending_docs',
      createdAt: now,
      updatedAt: now,
      requiredDocCategories: const [
        RequiredDocCategory(category: 'wwcc', isRequired: true),
        RequiredDocCategory(category: 'cpr', isRequired: false),
      ],
    );

    expect(missingCategories(e, const []), {'wwcc'});
  });
}
