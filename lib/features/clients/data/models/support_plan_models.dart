import '../../utils/support_plan_keys.dart';

/// Participant support plan DTOs matching `/v1/clients/{id}/support-plans`
/// and `/v1/visits/{id}/shift-brief`.

class DisabilityHealthSection {
  const DisabilityHealthSection({
    this.primaryDisability = '',
    this.secondaryConditions = '',
    this.functionalLimitations = const [],
    this.functionalImpactSummary = '',
    this.communicationMethods = const [],
    this.mobilityNeeds = '',
    this.behaviourSupportPlan = false,
    this.medicationSchedule = '',
    this.gpName = '',
    this.gpPhone = '',
    this.supportIntensity = SupportPlanKeys.intensityStandard,
  });

  final String primaryDisability;
  final String secondaryConditions;
  final List<String> functionalLimitations;
  final String functionalImpactSummary;
  final List<String> communicationMethods;
  final String mobilityNeeds;
  final bool behaviourSupportPlan;
  final String medicationSchedule;
  final String gpName;
  final String gpPhone;
  final String supportIntensity;

  factory DisabilityHealthSection.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return DisabilityHealthSection(
      primaryDisability: m['primary_disability'] as String? ?? '',
      secondaryConditions: m['secondary_conditions'] as String? ?? '',
      functionalLimitations: _stringList(m['functional_limitations']),
      functionalImpactSummary: m['functional_impact_summary'] as String? ?? '',
      communicationMethods: _stringList(m['communication_methods']),
      mobilityNeeds: m['mobility_needs'] as String? ?? '',
      behaviourSupportPlan: m['behaviour_support_plan'] as bool? ?? false,
      medicationSchedule: m['medication_schedule'] as String? ?? '',
      gpName: m['gp_name'] as String? ?? '',
      gpPhone: m['gp_phone'] as String? ?? '',
      supportIntensity: m['support_intensity'] as String? ??
          SupportPlanKeys.intensityStandard,
    );
  }

  Map<String, dynamic> toJson() => {
        'primary_disability': primaryDisability,
        'secondary_conditions': secondaryConditions,
        'functional_limitations': functionalLimitations,
        'functional_impact_summary': functionalImpactSummary,
        'communication_methods': communicationMethods,
        'mobility_needs': mobilityNeeds,
        'behaviour_support_plan': behaviourSupportPlan,
        'medication_schedule': medicationSchedule,
        'gp_name': gpName,
        'gp_phone': gpPhone,
        'support_intensity': supportIntensity,
      };
}

class LivingSection {
  const LivingSection({
    this.residenceType = SupportPlanKeys.residencePrivateHome,
    this.householdMembers = '',
    this.informalSupports = '',
  });

  final String residenceType;
  final String householdMembers;
  final String informalSupports;

  factory LivingSection.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return LivingSection(
      residenceType: m['residence_type'] as String? ??
          SupportPlanKeys.residencePrivateHome,
      householdMembers: m['household_members'] as String? ?? '',
      informalSupports: m['informal_supports'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'residence_type': residenceType,
        'household_members': householdMembers,
        'informal_supports': informalSupports,
      };
}

class SupportPlanGoal {
  const SupportPlanGoal({
    this.id = '',
    this.ndisGoal = '',
    this.strategy = '',
    this.measure = '',
    this.workerInstructions = '',
    this.sortOrder = 0,
  });

  final String id;
  final String ndisGoal;
  final String strategy;
  final String measure;
  final String workerInstructions;
  final int sortOrder;

  factory SupportPlanGoal.fromJson(Map<String, dynamic> json) {
    return SupportPlanGoal(
      id: json['id'] as String? ?? '',
      ndisGoal: json['ndis_goal'] as String? ?? '',
      strategy: json['strategy'] as String? ?? '',
      measure: json['measure'] as String? ?? '',
      workerInstructions: json['worker_instructions'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ndis_goal': ndisGoal,
        'strategy': strategy,
        'measure': measure,
        'worker_instructions': workerInstructions,
        'sort_order': sortOrder,
      };
}

class PreferencesSection {
  const PreferencesSection({
    this.preferredSupportStyle = '',
    this.routines = '',
    this.interestsStrengths = '',
    this.culturalNotes = '',
  });

  final String preferredSupportStyle;
  final String routines;
  final String interestsStrengths;
  final String culturalNotes;

  factory PreferencesSection.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return PreferencesSection(
      preferredSupportStyle: m['preferred_support_style'] as String? ?? '',
      routines: m['routines'] as String? ?? '',
      interestsStrengths: m['interests_strengths'] as String? ?? '',
      culturalNotes: m['cultural_notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'preferred_support_style': preferredSupportStyle,
        'routines': routines,
        'interests_strengths': interestsStrengths,
        'cultural_notes': culturalNotes,
      };
}

class RiskSection {
  const RiskSection({
    this.summary = '',
    this.behavioursOfConcern = '',
    this.triggers = '',
    this.deEscalation = '',
    this.crisisResponse = '',
  });

  final String summary;
  final String behavioursOfConcern;
  final String triggers;
  final String deEscalation;
  final String crisisResponse;

  factory RiskSection.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return RiskSection(
      summary: m['summary'] as String? ?? '',
      behavioursOfConcern: m['behaviours_of_concern'] as String? ?? '',
      triggers: m['triggers'] as String? ?? '',
      deEscalation: m['de_escalation'] as String? ?? '',
      crisisResponse: m['crisis_response'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'behaviours_of_concern': behavioursOfConcern,
        'triggers': triggers,
        'de_escalation': deEscalation,
        'crisis_response': crisisResponse,
      };
}

class ScheduleSection {
  const ScheduleSection({
    this.serviceDays = '',
    this.typicalTimes = '',
    this.recommendedHoursNote = '',
  });

  final String serviceDays;
  final String typicalTimes;
  final String recommendedHoursNote;

  factory ScheduleSection.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    return ScheduleSection(
      serviceDays: m['service_days'] as String? ?? '',
      typicalTimes: m['typical_times'] as String? ?? '',
      recommendedHoursNote: m['recommended_hours_note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'service_days': serviceDays,
        'typical_times': typicalTimes,
        'recommended_hours_note': recommendedHoursNote,
      };
}

/// Care body for a support plan. [toJson] always emits every section (OV1).
class SupportPlanBody {
  const SupportPlanBody({
    this.disabilityHealth = const DisabilityHealthSection(),
    this.living = const LivingSection(),
    this.goals = const [],
    this.serviceCategories = const [],
    this.preferences = const PreferencesSection(),
    this.risk = const RiskSection(),
    this.schedule = const ScheduleSection(),
  });

  final DisabilityHealthSection disabilityHealth;
  final LivingSection living;
  final List<SupportPlanGoal> goals;
  final List<String> serviceCategories;
  final PreferencesSection preferences;
  final RiskSection risk;
  final ScheduleSection schedule;

  factory SupportPlanBody.fromJson(Map<String, dynamic>? json) {
    final m = json ?? const <String, dynamic>{};
    final goalsRaw = m[SupportPlanKeys.goals];
    return SupportPlanBody(
      disabilityHealth: DisabilityHealthSection.fromJson(
        _asMap(m[SupportPlanKeys.disabilityHealth]),
      ),
      living: LivingSection.fromJson(_asMap(m[SupportPlanKeys.living])),
      goals: goalsRaw is List
          ? goalsRaw
              .whereType<Map>()
              .map((e) => SupportPlanGoal.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      serviceCategories: _stringList(m[SupportPlanKeys.serviceCategories]),
      preferences: PreferencesSection.fromJson(
        _asMap(m[SupportPlanKeys.preferences]),
      ),
      risk: RiskSection.fromJson(_asMap(m[SupportPlanKeys.risk])),
      schedule: ScheduleSection.fromJson(_asMap(m[SupportPlanKeys.schedule])),
    );
  }

  /// Full nested snake_case map for PATCH body full-replace (OV1).
  Map<String, dynamic> toJson() => {
        SupportPlanKeys.disabilityHealth: disabilityHealth.toJson(),
        SupportPlanKeys.living: living.toJson(),
        SupportPlanKeys.goals: goals.map((g) => g.toJson()).toList(),
        SupportPlanKeys.serviceCategories: serviceCategories,
        SupportPlanKeys.preferences: preferences.toJson(),
        SupportPlanKeys.risk: risk.toJson(),
        SupportPlanKeys.schedule: schedule.toJson(),
      };
}

class SupportPlanDto {
  const SupportPlanDto({
    required this.id,
    required this.clientId,
    required this.status,
    required this.body,
    required this.bodyInvalid,
    required this.createdAt,
    required this.updatedAt,
    this.nextReviewAt,
    this.preparedByUserId,
    this.preparedAt,
    this.reviewOverdue,
  });

  final String id;
  final String clientId;
  final String status;
  final String? nextReviewAt;
  final String? preparedByUserId;
  final DateTime? preparedAt;
  final SupportPlanBody body;
  final bool bodyInvalid;
  final bool? reviewOverdue;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportPlanDto.fromJson(Map<String, dynamic> json) {
    return SupportPlanDto(
      id: json['id'].toString(),
      clientId: json['client_id'].toString(),
      status: json['status'] as String? ?? SupportPlanKeys.statusDraft,
      nextReviewAt: json['next_review_at'] as String?,
      preparedByUserId: json['prepared_by_user_id']?.toString(),
      preparedAt: _parseDateTime(json['prepared_at']),
      body: SupportPlanBody.fromJson(_asMap(json['body'])),
      bodyInvalid: json['body_invalid'] as bool? ?? false,
      reviewOverdue: json['review_overdue'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class SupportPlanCreateRequest {
  const SupportPlanCreateRequest({this.body = const SupportPlanBody()});

  final SupportPlanBody body;

  Map<String, dynamic> toJson() => {'body': body.toJson()};
}

class SupportPlanUpdateRequest {
  const SupportPlanUpdateRequest({
    this.body,
    this.status,
    this.nextReviewAt,
  });

  final SupportPlanBody? body;
  final String? status;
  final String? nextReviewAt;

  Map<String, dynamic> toJson() => {
        if (body != null) 'body': body!.toJson(),
        if (status != null) 'status': status,
        if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      };
}

/// Contractor / staff shift-brief projector (`ShiftBriefOut`).
class ShiftBriefDto {
  const ShiftBriefDto({
    required this.clientId,
    required this.clientName,
    required this.planBodyInvalid,
    this.accessNotes,
    this.allergies,
    this.supportPlanId,
    this.supportIntensity,
    this.communicationMethods = const [],
    this.mobilityNeeds,
    this.medicationSchedule,
    this.behaviourSupportPlan,
    this.serviceCategories = const [],
    this.goals = const [],
    this.routines,
    this.preferredSupportStyle,
    this.behavioursOfConcern,
    this.triggers,
    this.deEscalation,
    this.crisisResponse,
    this.informalSupports,
  });

  final String clientId;
  final String clientName;
  final String? accessNotes;
  final String? allergies;
  final String? supportPlanId;
  final bool planBodyInvalid;
  final String? supportIntensity;
  final List<String> communicationMethods;
  final String? mobilityNeeds;
  final String? medicationSchedule;
  final bool? behaviourSupportPlan;
  final List<String> serviceCategories;
  final List<Map<String, dynamic>> goals;
  final String? routines;
  final String? preferredSupportStyle;
  final String? behavioursOfConcern;
  final String? triggers;
  final String? deEscalation;
  final String? crisisResponse;
  final String? informalSupports;

  factory ShiftBriefDto.fromJson(Map<String, dynamic> json) {
    final goalsRaw = json['goals'];
    return ShiftBriefDto(
      clientId: json['client_id'].toString(),
      clientName: json['client_name'] as String? ?? '',
      accessNotes: json['access_notes'] as String?,
      allergies: json['allergies'] as String?,
      supportPlanId: json['support_plan_id']?.toString(),
      planBodyInvalid: json['plan_body_invalid'] as bool? ?? false,
      supportIntensity: json['support_intensity'] as String?,
      communicationMethods: _stringList(json['communication_methods']),
      mobilityNeeds: json['mobility_needs'] as String?,
      medicationSchedule: json['medication_schedule'] as String?,
      behaviourSupportPlan: json['behaviour_support_plan'] as bool?,
      serviceCategories: _stringList(json['service_categories']),
      goals: goalsRaw is List
          ? goalsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false)
          : const [],
      routines: json['routines'] as String?,
      preferredSupportStyle: json['preferred_support_style'] as String?,
      behavioursOfConcern: json['behaviours_of_concern'] as String?,
      triggers: json['triggers'] as String?,
      deEscalation: json['de_escalation'] as String?,
      crisisResponse: json['crisis_response'] as String?,
      informalSupports: json['informal_supports'] as String?,
    );
  }
}

Map<String, dynamic>? _asMap(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.parse(raw);
}
