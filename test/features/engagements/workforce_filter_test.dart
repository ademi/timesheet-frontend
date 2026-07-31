import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/utils/missing_categories.dart';

EngagementOut _engagement({
  required String contractorId,
  List<RequiredDocCategory> categories = const [],
}) {
  final now = DateTime.utc(2026, 1, 1);
  return EngagementOut(
    id: 'e1',
    tenantId: 't1',
    contractorId: contractorId,
    status: 'pending_docs',
    createdAt: now,
    updatedAt: now,
    requiredDocCategories: categories,
  );
}

CredentialOut _credential({
  required String contractorId,
  required String type,
  String evidencePresence = 'present',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return CredentialOut(
    id: 'c1',
    contractorId: contractorId,
    credentialType: type,
    status: 'active',
    provenanceState: 'verified',
    evidencePresence: evidencePresence,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('missing docs filter uses required categories and credentials', () {
    final engagement = _engagement(
      contractorId: 'p1',
      categories: const [
        RequiredDocCategory(category: 'wwcc', isRequired: true),
      ],
    );
    expect(
      missingCategories(engagement, const []).isNotEmpty,
      isTrue,
    );
    expect(
      missingCategories(
        engagement,
        [_credential(contractorId: 'p1', type: 'wwcc')],
      ).isEmpty,
      isTrue,
    );
  });
}
