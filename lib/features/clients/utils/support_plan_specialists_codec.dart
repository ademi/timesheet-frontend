import '../data/models/client_profile_models.dart';
import '../models/support_plan_professional_fields.dart';
import '../models/support_plan_specialist_entry.dart';
import '../models/support_plan_specialist_types.dart';
import 'onboarding_keys.dart';

/// Encode/decode [OnboardingKeys.supportPlanSpecialists] JSON array facts.
abstract final class SupportPlanSpecialistsCodec {
  static List<SupportPlanSpecialistEntry> fromFactValue(Object? valueJson) {
    if (valueJson == null) return [];
    List<dynamic>? rawList;
    if (valueJson is List) {
      rawList = valueJson;
    } else if (valueJson is String) {
      // Defensive: some APIs may stringify JSON arrays.
      return const [];
    }
    if (rawList == null) return [];
    final out = <SupportPlanSpecialistEntry>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      try {
        out.add(
          SupportPlanSpecialistEntry.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        // skip corrupt row
      }
    }
    return out;
  }

  static const _legacyDefs = <_LegacySpecialistDef>[
    _LegacySpecialistDef(
      type: SupportPlanSpecialistTypes.supportCoordinator,
      nameKey: OnboardingKeys.supportCoordinatorName,
      companyKey: OnboardingKeys.supportCoordinatorCompany,
      abnAcnKey: OnboardingKeys.supportCoordinatorAbnAcn,
      orgIdKey: OnboardingKeys.supportCoordinatorOrgId,
      phoneKey: OnboardingKeys.supportCoordinatorPhone,
      emailKey: OnboardingKeys.supportCoordinatorEmail,
      addressKey: OnboardingKeys.supportCoordinatorAddress,
    ),
    _LegacySpecialistDef(
      type: SupportPlanSpecialistTypes.behaviouralTherapist,
      nameKey: OnboardingKeys.behaviouralTherapistName,
      companyKey: OnboardingKeys.behaviouralTherapistCompany,
      abnAcnKey: OnboardingKeys.behaviouralTherapistAbnAcn,
      orgIdKey: OnboardingKeys.behaviouralTherapistOrgId,
      phoneKey: OnboardingKeys.behaviouralTherapistPhone,
      emailKey: OnboardingKeys.behaviouralTherapistEmail,
      addressKey: OnboardingKeys.behaviouralTherapistAddress,
    ),
    _LegacySpecialistDef(
      type: SupportPlanSpecialistTypes.speechTherapist,
      nameKey: OnboardingKeys.speechTherapistName,
      companyKey: OnboardingKeys.speechTherapistCompany,
      abnAcnKey: OnboardingKeys.speechTherapistAbnAcn,
      orgIdKey: OnboardingKeys.speechTherapistOrgId,
      phoneKey: OnboardingKeys.speechTherapistPhone,
      emailKey: OnboardingKeys.speechTherapistEmail,
      addressKey: OnboardingKeys.speechTherapistAddress,
    ),
    _LegacySpecialistDef(
      type: SupportPlanSpecialistTypes.occupationalTherapist,
      nameKey: OnboardingKeys.occupationalTherapistName,
      companyKey: OnboardingKeys.occupationalTherapistCompany,
      abnAcnKey: OnboardingKeys.occupationalTherapistAbnAcn,
      orgIdKey: OnboardingKeys.occupationalTherapistOrgId,
      phoneKey: OnboardingKeys.occupationalTherapistPhone,
      emailKey: OnboardingKeys.occupationalTherapistEmail,
      addressKey: OnboardingKeys.occupationalTherapistAddress,
    ),
    _LegacySpecialistDef(
      type: SupportPlanSpecialistTypes.physiotherapist,
      nameKey: OnboardingKeys.physiotherapistName,
      companyKey: OnboardingKeys.physiotherapistCompany,
      abnAcnKey: OnboardingKeys.physiotherapistAbnAcn,
      orgIdKey: OnboardingKeys.physiotherapistOrgId,
      phoneKey: OnboardingKeys.physiotherapistPhone,
      emailKey: OnboardingKeys.physiotherapistEmail,
      addressKey: OnboardingKeys.physiotherapistAddress,
    ),
  ];

  static String? _readFact(Iterable<ClientProfileFactOut> facts, String key) {
    for (final f in facts) {
      if (f.requirementKey == key) {
        final v = f.valueJson;
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }
    }
    return null;
  }

  static List<SupportPlanSpecialistEntry> fromLegacyFacts(
    Iterable<ClientProfileFactOut> facts,
  ) {
    final out = <SupportPlanSpecialistEntry>[];
    for (final def in _legacyDefs) {
      final fields = SupportPlanProfessionalFields();
      fields.nameCtrl.text = _readFact(facts, def.nameKey) ?? '';
      fields.companyCtrl.text = _readFact(facts, def.companyKey) ?? '';
      fields.abnAcnCtrl.text = _readFact(facts, def.abnAcnKey) ?? '';
      fields.orgIdCtrl.text = _readFact(facts, def.orgIdKey) ?? '';
      fields.phoneCtrl.text = _readFact(facts, def.phoneKey) ?? '';
      fields.emailCtrl.text = _readFact(facts, def.emailKey) ?? '';
      fields.addressCtrl.text = _readFact(facts, def.addressKey) ?? '';
      final hasData = fields.nameCtrl.text.isNotEmpty ||
          fields.companyCtrl.text.isNotEmpty ||
          fields.abnAcnCtrl.text.isNotEmpty ||
          fields.orgIdCtrl.text.isNotEmpty ||
          fields.phoneCtrl.text.isNotEmpty ||
          fields.emailCtrl.text.isNotEmpty ||
          fields.addressCtrl.text.isNotEmpty;
      if (!hasData) {
        fields.dispose();
        continue;
      }
      out.add(
        SupportPlanSpecialistEntry.fromLegacy(
          type: def.type,
          fields: fields,
        ),
      );
    }
    return out;
  }

  static List<SupportPlanSpecialistEntry> resolveFromFacts(
    Iterable<ClientProfileFactOut> facts,
  ) {
    Object? jsonValue;
    for (final f in facts) {
      if (f.requirementKey == OnboardingKeys.supportPlanSpecialists) {
        jsonValue = f.valueJson;
        break;
      }
    }
    final fromJson = fromFactValue(jsonValue);
    if (fromJson.isNotEmpty) return fromJson;
    return fromLegacyFacts(facts);
  }

  static List<Map<String, dynamic>> toFactValue(
    Iterable<SupportPlanSpecialistEntry> entries,
  ) {
    return [
      for (final e in entries)
        if (e.hasAnyFieldFilled) e.toJson(),
    ];
  }
}

class _LegacySpecialistDef {
  const _LegacySpecialistDef({
    required this.type,
    required this.nameKey,
    required this.companyKey,
    required this.abnAcnKey,
    required this.orgIdKey,
    required this.phoneKey,
    required this.emailKey,
    required this.addressKey,
  });

  final String type;
  final String nameKey;
  final String companyKey;
  final String abnAcnKey;
  final String orgIdKey;
  final String phoneKey;
  final String emailKey;
  final String addressKey;
}
