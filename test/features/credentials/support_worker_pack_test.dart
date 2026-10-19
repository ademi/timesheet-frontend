import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/utils/support_worker_pack.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19);

  EngagementOut eng({
    List<String> requiredResolved = const [],
    List<String>? apiMissing,
    Map<String, bool?> flags = const {},
    int? points,
  }) => EngagementOut(
    id: 'e1',
    tenantId: 't1',
    contractorId: 'c1',
    status: 'pending_docs',
    createdAt: now,
    updatedAt: now,
    requiredResolved: requiredResolved,
    apiMissing: apiMissing,
    onboardingFlags: flags,
    photoIdPointsTotal: points,
  );

  CredentialOut cred(String type, {int? points}) => CredentialOut(
    id: 'id-$type',
    contractorId: 'c1',
    credentialType: type,
    status: 'active',
    provenanceState: 'self_reported',
    evidencePresence: 'present',
    idPoints: points,
    createdAt: now,
    updatedAt: now,
  );

  test('resolveCreateType maps relevant_qualification to cert_iii', () {
    expect(
      SupportWorkerPack.resolveCreateType('relevant_qualification'),
      'cert_iii',
    );
    expect(SupportWorkerPack.resolveCreateType('wwcc'), 'wwcc');
  });

  test('photo ID points use API total when present', () {
    final sections = buildPackChecklistSections(
      engagement: eng(
        requiredResolved: const ['passport_id'],
        points: 70,
        flags: const {
          'wwcc_applicable': false,
          'qualifications_applicable': false,
          'drives_participants': false,
          'uses_own_vehicle': false,
        },
      ),
      credentials: [cred('passport_id', points: 70)],
    );
    expect(sections.photoIdRequired, isTrue);
    expect(sections.photoIdPointsTotal, 70);
    expect(sections.photoIdSatisfied, isFalse);
  });

  test('conditional wwcc required when flag true and missing', () {
    final sections = buildPackChecklistSections(
      engagement: eng(
        requiredResolved: SupportWorkerPack.alwaysRequired.toList()
          ..add('wwcc'),
        apiMissing: const ['wwcc'],
        flags: const {
          'wwcc_applicable': true,
          'qualifications_applicable': false,
          'drives_participants': false,
          'uses_own_vehicle': false,
        },
      ),
      credentials: const [],
    );
    final wwcc = sections.conditionals.firstWhere((c) => c.category == 'wwcc');
    expect(wwcc.isRequired, isTrue);
    expect(wwcc.isMissing, isTrue);
    expect(sections.missingForCreate, contains('wwcc'));
  });

  test('qual sentinel resolves into missing create as cert_iii', () {
    final sections = buildPackChecklistSections(
      engagement: eng(
        requiredResolved: const ['relevant_qualification'],
        apiMissing: const ['relevant_qualification'],
        flags: const {
          'wwcc_applicable': false,
          'qualifications_applicable': true,
          'drives_participants': false,
          'uses_own_vehicle': false,
        },
      ),
      credentials: const [],
    );
    expect(sections.missingForCreate, contains('cert_iii'));
  });

  test('create request includes id_points when set', () {
    const request = CredentialCreateRequest(
      credentialType: 'passport_id',
      noticeEventId: 'n1',
      evidenceDocumentIds: ['d1'],
      idPoints: 70,
    );
    expect(request.toJson()['id_points'], 70);
  });
}
