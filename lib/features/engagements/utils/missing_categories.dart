import '../../credentials/data/models/credential_models.dart';
import '../data/models/engagement_models.dart';

const _evidenceNotPresent = {'none', 'absent', 'quarantined'};

/// Beta rule: credential row exists with usable evidence (not none/absent/quarantined).
bool credentialHasPresentEvidence(CredentialOut credential) =>
    !_evidenceNotPresent.contains(credential.evidencePresence);

/// Required doc categories on [engagement] without a matching credential with evidence.
Set<String> missingCategories(
  EngagementOut engagement,
  List<CredentialOut> credentials,
) {
  final required = engagement.requiredDocCategories
      .where((c) => c.isRequired)
      .map((c) => c.category)
      .toSet();
  final have = credentials
      .where(credentialHasPresentEvidence)
      .map((c) => c.credentialType)
      .toSet();
  return required.where((c) => !have.contains(c)).toSet();
}
