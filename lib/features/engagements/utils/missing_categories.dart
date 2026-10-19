import '../../credentials/data/models/credential_models.dart';
import '../data/models/engagement_models.dart';

const _evidenceNotPresent = {'none', 'absent', 'quarantined'};

const _photoIdTypes = {'passport_id', 'drivers_licence'};
const _qualificationTypes = {
  'cert_iii',
  'nursing_bachelor',
  'nursing_diploma',
  'other_health_qualification',
  'trade_certificate',
};
const _relevantQualificationSentinel = 'relevant_qualification';

/// Beta rule: credential row exists with usable evidence (not none/absent/quarantined).
bool credentialHasPresentEvidence(CredentialOut credential) =>
    !_evidenceNotPresent.contains(credential.evidencePresence);

int sumPhotoIdPoints(List<CredentialOut> credentials) {
  var sum = 0;
  for (final c in credentials) {
    if (!_photoIdTypes.contains(c.credentialType)) continue;
    if (!credentialHasPresentEvidence(c)) continue;
    sum += c.idPoints ?? (c.credentialType == 'passport_id' ? 100 : 0);
  }
  return sum;
}

/// Required doc categories on [engagement] without a matching credential with evidence.
///
/// Prefers API `missing` when present. Optional catalog types (e.g. `visa`) never
/// count as missing. Photo ID stays missing until points ≥ 100.
Set<String> missingCategories(
  EngagementOut engagement,
  List<CredentialOut> credentials,
) {
  if (engagement.apiMissing != null) {
    return engagement.apiMissing!
        .where((c) => !isOptionalCredentialType(c))
        .toSet();
  }

  final required =
      engagement.resolvedRequiredCategories
          .where((c) => !isOptionalCredentialType(c))
          .toSet();

  final haveTypes =
      credentials
          .where(credentialHasPresentEvidence)
          .map((c) => c.credentialType)
          .toSet();

  final missing = <String>{};
  for (final code in required) {
    if (code == _relevantQualificationSentinel ||
        _qualificationTypes.contains(code)) {
      final hasQual = haveTypes.any(_qualificationTypes.contains);
      if (!hasQual) {
        missing.add(_relevantQualificationSentinel);
      }
      continue;
    }
    if (code == 'passport_id') {
      final points =
          engagement.photoIdPointsTotal ?? sumPhotoIdPoints(credentials);
      if (points < 100) missing.add('passport_id');
      continue;
    }
    if (!haveTypes.contains(code)) missing.add(code);
  }
  return missing;
}
