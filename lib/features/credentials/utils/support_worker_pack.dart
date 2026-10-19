import '../../contractor_me/data/models/contractor_me_models.dart';
import '../data/models/credential_models.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/utils/missing_categories.dart';

/// Global Support Worker pack (v1) — mirrors BE `support_worker_v1`.
abstract final class SupportWorkerPack {
  static const documentPackId = 'support_worker_v1';

  static const alwaysRequired = <String>{
    'resume',
    'passport_id',
    'ndis_worker_screening',
    'police_check',
    'first_aid',
    'cpr',
    'worker_orientation',
    'infection_control',
  };

  /// Qual types that satisfy the qualifications_applicable conditional.
  static const qualificationTypes = <String>{
    'cert_iii',
    'nursing_bachelor',
    'nursing_diploma',
    'other_health_qualification',
    'trade_certificate',
  };

  /// Sentinel used by BE when quals flag is on.
  static const relevantQualificationSentinel = 'relevant_qualification';

  /// Types that contribute to Photo ID / 100 points.
  static const photoIdTypes = <String>{'passport_id', 'drivers_licence'};

  static const optional = <String>{'visa'};

  static const conditionalFlagCategories = <String, List<String>>{
    OnboardingFlagKeys.wwccApplicable: ['wwcc'],
    OnboardingFlagKeys.qualificationsApplicable: [
      relevantQualificationSentinel,
    ],
    OnboardingFlagKeys.drivesParticipants: ['drivers_licence'],
    OnboardingFlagKeys.usesOwnVehicle: [
      'vehicle_registration',
      'insurance',
    ],
  };

  /// Default create type when missing list uses the quals sentinel.
  static String resolveCreateType(String category) {
    if (category == relevantQualificationSentinel) return 'cert_iii';
    return category;
  }

  static bool isPhotoIdType(String type) => photoIdTypes.contains(type);

  static bool isQualificationType(String type) =>
      qualificationTypes.contains(type) ||
      type == relevantQualificationSentinel;

  static int photoIdPointsTotal(
    EngagementOut engagement,
    List<CredentialOut> credentials,
  ) =>
      engagement.photoIdPointsTotal ?? sumPhotoIdPoints(credentials);
}

/// One conditional checklist row (may be locked until Profile flags answered).
class ConditionalChecklistItem {
  const ConditionalChecklistItem({
    required this.category,
    required this.flagKey,
    required this.flagAnswered,
    required this.flagValue,
    required this.isMissing,
  });

  final String category;
  final String flagKey;
  final bool flagAnswered;
  final bool? flagValue;
  final bool isMissing;

  bool get isLocked => !flagAnswered;
  bool get isRequired => flagAnswered && flagValue == true;
}

/// Structured pack sections for [EngagementDocsChecklist].
class PackChecklistSections {
  const PackChecklistSections({
    required this.always,
    required this.conditionals,
    required this.optional,
    required this.missingForCreate,
    required this.photoIdPointsTotal,
    required this.photoIdRequired,
  });

  final List<String> always;
  final List<ConditionalChecklistItem> conditionals;
  final List<String> optional;
  final List<String> missingForCreate;
  final int photoIdPointsTotal;
  final bool photoIdRequired;

  bool get photoIdSatisfied =>
      !photoIdRequired || photoIdPointsTotal >= 100;
}

/// Builds Always / Conditional / Optional sections from engagement + flags.
PackChecklistSections buildPackChecklistSections({
  required EngagementOut engagement,
  required List<CredentialOut> credentials,
}) {
  final flags = engagement.onboardingFlags;
  final requiredResolved = engagement.resolvedRequiredCategories;
  final missing = missingCategories(engagement, credentials);

  final always =
      requiredResolved
          .where(SupportWorkerPack.alwaysRequired.contains)
          .toList()
        ..sort();

  // Include always-pack codes even if only in required_doc_categories legacy.
  if (always.isEmpty) {
    always.addAll(
      engagement.requiredDocCategories
          .where((c) => c.isRequired)
          .map((c) => c.category)
          .where(SupportWorkerPack.alwaysRequired.contains),
    );
    always.sort();
  }

  final conditionals = <ConditionalChecklistItem>[];
  final seenConditional = <String>{};

  void addConditional(String category, String flagKey) {
    if (seenConditional.contains(category)) return;
    seenConditional.add(category);
    final answered = flags.containsKey(flagKey) && flags[flagKey] != null;
    final value = flags[flagKey];
    final isMissing =
        answered &&
        value == true &&
        (missing.contains(category) ||
            (category == SupportWorkerPack.relevantQualificationSentinel &&
                missing.any(SupportWorkerPack.isQualificationType)));
    conditionals.add(
      ConditionalChecklistItem(
        category: category,
        flagKey: flagKey,
        flagAnswered: answered,
        flagValue: value,
        isMissing: isMissing,
      ),
    );
  }

  for (final entry in SupportWorkerPack.conditionalFlagCategories.entries) {
    for (final cat in entry.value) {
      addConditional(cat, entry.key);
    }
  }

  // Staff extras / resolved quals types beyond sentinel.
  for (final code in requiredResolved) {
    if (SupportWorkerPack.alwaysRequired.contains(code)) continue;
    if (SupportWorkerPack.optional.contains(code)) continue;
    if (seenConditional.contains(code)) continue;
    if (SupportWorkerPack.qualificationTypes.contains(code)) {
      addConditional(
        SupportWorkerPack.relevantQualificationSentinel,
        OnboardingFlagKeys.qualificationsApplicable,
      );
      continue;
    }
    // Unknown conditional/extra — treat as always-required display if required.
    if (!always.contains(code)) {
      always.add(code);
    }
  }
  always.sort();

  final optional = SupportWorkerPack.optional.toList()..sort();

  final missingForCreate =
      missing
          .map(SupportWorkerPack.resolveCreateType)
          .where((c) => !SupportWorkerPack.optional.contains(c))
          .toSet()
          .toList()
        ..sort();

  final photoIdRequired =
      always.contains('passport_id') || requiredResolved.contains('passport_id');

  return PackChecklistSections(
    always: always,
    conditionals: conditionals,
    optional: optional,
    missingForCreate: missingForCreate,
    photoIdPointsTotal: SupportWorkerPack.photoIdPointsTotal(
      engagement,
      credentials,
    ),
    photoIdRequired: photoIdRequired,
  );
}
