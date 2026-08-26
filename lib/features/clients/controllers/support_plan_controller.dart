import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/support_plan_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/support_plan_keys.dart';

/// Thin Support Plan form: Care body + Review (status / next review).
class SupportPlanController extends GetxController {
  SupportPlanController({
    required ClientsRepository repository,
    String? clientId,
    String? planId,
    this.clientName,
    this.ndisNumber,
  })  : _repository = repository,
        clientId = clientId ?? '',
        _initialPlanId = planId;

  final ClientsRepository _repository;

  /// Optional overrides for tests (skip Get.arguments).
  final String? clientName;
  final String? ndisNumber;

  String clientId;
  String? _initialPlanId;

  final planId = RxnString();
  final status = SupportPlanKeys.statusDraft.obs;
  final nextReviewAt = RxnString();
  final needsBodyRepair = false.obs;
  final reviewOverdue = false.obs;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  /// Last PATCH/create body map (for OV1 full-replace tests).
  Map<String, dynamic>? lastSavedPayload;

  // ── Disability / health ───────────────────────────────────────────────
  final primaryDisabilityCtrl = TextEditingController();
  final secondaryConditionsCtrl = TextEditingController();
  final functionalImpactCtrl = TextEditingController();
  final mobilityNeedsCtrl = TextEditingController();
  final medicationScheduleCtrl = TextEditingController();
  final gpNameCtrl = TextEditingController();
  final gpPhoneCtrl = TextEditingController();
  final behaviourSupportPlan = false.obs;
  final supportIntensity = SupportPlanKeys.intensityStandard.obs;
  final functionalLimitations = <String>[].obs;
  final communicationMethods = <String>[].obs;

  // ── Living ────────────────────────────────────────────────────────────
  final residenceType = SupportPlanKeys.residencePrivateHome.obs;
  final householdMembersCtrl = TextEditingController();
  final informalSupportsCtrl = TextEditingController();

  // ── Goals ─────────────────────────────────────────────────────────────
  final goals = <SupportPlanGoalEditors>[].obs;

  // ── Categories ────────────────────────────────────────────────────────
  final serviceCategories = <String>[].obs;

  // ── Preferences ───────────────────────────────────────────────────────
  final preferredSupportStyleCtrl = TextEditingController();
  final routinesCtrl = TextEditingController();
  final interestsStrengthsCtrl = TextEditingController();
  final culturalNotesCtrl = TextEditingController();

  // ── Risk ──────────────────────────────────────────────────────────────
  final riskSummaryCtrl = TextEditingController();
  final behavioursOfConcernCtrl = TextEditingController();
  final triggersCtrl = TextEditingController();
  final deEscalationCtrl = TextEditingController();
  final crisisResponseCtrl = TextEditingController();

  // ── Schedule ──────────────────────────────────────────────────────────
  final serviceDaysCtrl = TextEditingController();
  final typicalTimesCtrl = TextEditingController();
  final recommendedHoursCtrl = TextEditingController();

  static const functionalLimitationOptions = [
    SupportPlanKeys.limitationHearing,
    SupportPlanKeys.limitationSpeech,
    SupportPlanKeys.limitationVision,
    SupportPlanKeys.limitationMobility,
    SupportPlanKeys.limitationSwallowing,
    SupportPlanKeys.limitationBreathing,
    SupportPlanKeys.limitationCognition,
    SupportPlanKeys.limitationAdls,
    SupportPlanKeys.limitationOther,
  ];

  static const communicationOptions = [
    SupportPlanKeys.commVerbal,
    SupportPlanKeys.commWritten,
    SupportPlanKeys.commAuslan,
    SupportPlanKeys.commSignLanguage,
    SupportPlanKeys.commPicture,
    SupportPlanKeys.commGesture,
    SupportPlanKeys.commAssistiveTech,
    SupportPlanKeys.commOther,
  ];

  static const categoryOptions = [
    SupportPlanKeys.catHomemaking,
    SupportPlanKeys.catPersonalCare,
    SupportPlanKeys.catCompanion,
    SupportPlanKeys.catCommunityAccess,
    SupportPlanKeys.catTransport,
    SupportPlanKeys.catOther,
  ];

  static const intensityOptions = [
    SupportPlanKeys.intensityStandard,
    SupportPlanKeys.intensityComplex,
    SupportPlanKeys.intensityIntense,
  ];

  static const residenceOptions = [
    SupportPlanKeys.residencePrivateHome,
    SupportPlanKeys.residenceUnit,
    SupportPlanKeys.residenceSharedLiving,
    SupportPlanKeys.residenceSupportedAccommodation,
    SupportPlanKeys.residenceAgedCare,
    SupportPlanKeys.residenceCaravanPark,
    SupportPlanKeys.residenceOther,
  ];

  /// Activate requires a next review date (BE `next_review_at_required`).
  bool get canActivate {
    final review = nextReviewAt.value;
    return review != null && review.trim().isNotEmpty;
  }

  String get displayName => clientName ?? '';
  String? get displayNdis => ndisNumber;

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    if (clientId.isNotEmpty) {
      load();
    }
  }

  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      final id = args['clientId']?.toString();
      if (id != null && id.isNotEmpty) clientId = id;
      final pid = args['planId']?.toString();
      if (pid != null && pid.isNotEmpty) {
        _initialPlanId = pid;
        planId.value = pid;
      }
    }
  }

  Future<void> load() async {
    if (clientId.isEmpty) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      SupportPlanDto? dto;
      final existingId = _initialPlanId ?? planId.value;
      if (existingId != null && existingId.isNotEmpty) {
        dto = await _repository.getSupportPlan(clientId, existingId);
      } else {
        final plans = await _repository.listSupportPlans(clientId);
        for (final p in plans) {
          if (p.status == SupportPlanKeys.statusActive) {
            dto = p;
            break;
          }
        }
        dto ??= plans.isNotEmpty ? plans.first : null;
      }
      if (dto != null) {
        applyLoadedPlan(dto);
      } else {
        applyLoadedPlan(
          SupportPlanDto(
            id: '',
            clientId: clientId,
            status: SupportPlanKeys.statusDraft,
            body: const SupportPlanBody(),
            bodyInvalid: false,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
        planId.value = null;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Prefill form from GET (CR3: `body_invalid` → repair banner + empty defaults).
  void applyLoadedPlan(SupportPlanDto dto) {
    if (dto.id.isNotEmpty) planId.value = dto.id;
    status.value = dto.status;
    nextReviewAt.value = dto.nextReviewAt;
    needsBodyRepair.value = dto.bodyInvalid;
    reviewOverdue.value = dto.reviewOverdue == true;

    final body = dto.bodyInvalid ? const SupportPlanBody() : dto.body;
    _applyBody(body);
  }

  void _applyBody(SupportPlanBody body) {
    final dh = body.disabilityHealth;
    primaryDisabilityCtrl.text = dh.primaryDisability;
    secondaryConditionsCtrl.text = dh.secondaryConditions;
    functionalImpactCtrl.text = dh.functionalImpactSummary;
    mobilityNeedsCtrl.text = dh.mobilityNeeds;
    medicationScheduleCtrl.text = dh.medicationSchedule;
    gpNameCtrl.text = dh.gpName;
    gpPhoneCtrl.text = dh.gpPhone;
    behaviourSupportPlan.value = dh.behaviourSupportPlan;
    supportIntensity.value = dh.supportIntensity;
    functionalLimitations.assignAll(dh.functionalLimitations);
    communicationMethods.assignAll(dh.communicationMethods);

    residenceType.value = body.living.residenceType;
    householdMembersCtrl.text = body.living.householdMembers;
    informalSupportsCtrl.text = body.living.informalSupports;

    _replaceGoals(body.goals);
    serviceCategories.assignAll(body.serviceCategories);

    preferredSupportStyleCtrl.text = body.preferences.preferredSupportStyle;
    routinesCtrl.text = body.preferences.routines;
    interestsStrengthsCtrl.text = body.preferences.interestsStrengths;
    culturalNotesCtrl.text = body.preferences.culturalNotes;

    riskSummaryCtrl.text = body.risk.summary;
    behavioursOfConcernCtrl.text = body.risk.behavioursOfConcern;
    triggersCtrl.text = body.risk.triggers;
    deEscalationCtrl.text = body.risk.deEscalation;
    crisisResponseCtrl.text = body.risk.crisisResponse;

    serviceDaysCtrl.text = body.schedule.serviceDays;
    typicalTimesCtrl.text = body.schedule.typicalTimes;
    recommendedHoursCtrl.text = body.schedule.recommendedHoursNote;
  }

  void _replaceGoals(List<SupportPlanGoal> source) {
    for (final g in goals) {
      g.dispose();
    }
    goals.assignAll(source.map(SupportPlanGoalEditors.fromGoal));
  }

  void addGoal() {
    if (goals.length >= 20) return;
    goals.add(SupportPlanGoalEditors.empty(sortOrder: goals.length));
  }

  void removeGoal(int index) {
    if (index < 0 || index >= goals.length) return;
    goals[index].dispose();
    goals.removeAt(index);
    for (var i = 0; i < goals.length; i++) {
      goals[i].sortOrder = i;
    }
    goals.refresh();
  }

  void toggleLimitation(String key) {
    if (functionalLimitations.contains(key)) {
      functionalLimitations.remove(key);
    } else {
      functionalLimitations.add(key);
    }
  }

  void toggleCommunication(String key) {
    if (communicationMethods.contains(key)) {
      communicationMethods.remove(key);
    } else {
      communicationMethods.add(key);
    }
  }

  void toggleCategory(String key) {
    if (serviceCategories.contains(key)) {
      serviceCategories.remove(key);
    } else {
      serviceCategories.add(key);
    }
  }

  /// Always full nested body (OV1) — never dirty-fields-only.
  SupportPlanBody buildBody() {
    return SupportPlanBody(
      disabilityHealth: DisabilityHealthSection(
        primaryDisability: primaryDisabilityCtrl.text.trim(),
        secondaryConditions: secondaryConditionsCtrl.text.trim(),
        functionalLimitations: functionalLimitations.toList(growable: false),
        functionalImpactSummary: functionalImpactCtrl.text.trim(),
        communicationMethods: communicationMethods.toList(growable: false),
        mobilityNeeds: mobilityNeedsCtrl.text.trim(),
        behaviourSupportPlan: behaviourSupportPlan.value,
        medicationSchedule: medicationScheduleCtrl.text.trim(),
        gpName: gpNameCtrl.text.trim(),
        gpPhone: gpPhoneCtrl.text.trim(),
        supportIntensity: supportIntensity.value,
      ),
      living: LivingSection(
        residenceType: residenceType.value,
        householdMembers: householdMembersCtrl.text.trim(),
        informalSupports: informalSupportsCtrl.text.trim(),
      ),
      goals: [
        for (var i = 0; i < goals.length; i++) goals[i].toGoal(sortOrder: i),
      ],
      serviceCategories: serviceCategories.toList(growable: false),
      preferences: PreferencesSection(
        preferredSupportStyle: preferredSupportStyleCtrl.text.trim(),
        routines: routinesCtrl.text.trim(),
        interestsStrengths: interestsStrengthsCtrl.text.trim(),
        culturalNotes: culturalNotesCtrl.text.trim(),
      ),
      risk: RiskSection(
        summary: riskSummaryCtrl.text.trim(),
        behavioursOfConcern: behavioursOfConcernCtrl.text.trim(),
        triggers: triggersCtrl.text.trim(),
        deEscalation: deEscalationCtrl.text.trim(),
        crisisResponse: crisisResponseCtrl.text.trim(),
      ),
      schedule: ScheduleSection(
        serviceDays: serviceDaysCtrl.text.trim(),
        typicalTimes: typicalTimesCtrl.text.trim(),
        recommendedHoursNote: recommendedHoursCtrl.text.trim(),
      ),
    );
  }

  Future<void> saveDraft() async {
    await _persist(activate: false);
  }

  Future<void> activate() async {
    if (!canActivate) {
      errorMessage.value = 'Set a next review date before activating.';
      return;
    }
    status.value = SupportPlanKeys.statusActive;
    await _persist(activate: true);
  }

  Future<void> _persist({required bool activate}) async {
    if (clientId.isEmpty || isSaving.value) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final body = buildBody();
      final targetStatus =
          activate ? SupportPlanKeys.statusActive : SupportPlanKeys.statusDraft;
      status.value = targetStatus;

      var id = planId.value;
      if (id == null || id.isEmpty) {
        final createPayload = SupportPlanCreateRequest(body: body).toJson();
        lastSavedPayload = createPayload;
        final created =
            await _repository.createSupportPlan(clientId, createPayload);
        id = created.id;
        planId.value = id;
        if (!activate) {
          applyLoadedPlan(created);
          return;
        }
      }

      final update = SupportPlanUpdateRequest(
        body: body,
        status: targetStatus,
        nextReviewAt: nextReviewAt.value,
      );
      final payload = update.toJson();
      lastSavedPayload = payload;
      final idToPatch = id;
      if (idToPatch == null || idToPatch.isEmpty) {
        errorMessage.value = 'Missing plan id.';
        return;
      }
      final saved =
          await _repository.patchSupportPlan(clientId, idToPatch, payload);
      applyLoadedPlan(saved);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    primaryDisabilityCtrl.dispose();
    secondaryConditionsCtrl.dispose();
    functionalImpactCtrl.dispose();
    mobilityNeedsCtrl.dispose();
    medicationScheduleCtrl.dispose();
    gpNameCtrl.dispose();
    gpPhoneCtrl.dispose();
    householdMembersCtrl.dispose();
    informalSupportsCtrl.dispose();
    preferredSupportStyleCtrl.dispose();
    routinesCtrl.dispose();
    interestsStrengthsCtrl.dispose();
    culturalNotesCtrl.dispose();
    riskSummaryCtrl.dispose();
    behavioursOfConcernCtrl.dispose();
    triggersCtrl.dispose();
    deEscalationCtrl.dispose();
    crisisResponseCtrl.dispose();
    serviceDaysCtrl.dispose();
    typicalTimesCtrl.dispose();
    recommendedHoursCtrl.dispose();
    for (final g in goals) {
      g.dispose();
    }
    super.onClose();
  }
}

class SupportPlanGoalEditors {
  SupportPlanGoalEditors({
    required this.id,
    required this.sortOrder,
    required this.ndisGoal,
    required this.strategy,
    required this.measure,
    required this.workerInstructions,
  });

  factory SupportPlanGoalEditors.empty({required int sortOrder}) =>
      SupportPlanGoalEditors(
        id: 'g-${DateTime.now().microsecondsSinceEpoch}-$sortOrder',
        sortOrder: sortOrder,
        ndisGoal: TextEditingController(),
        strategy: TextEditingController(),
        measure: TextEditingController(),
        workerInstructions: TextEditingController(),
      );

  factory SupportPlanGoalEditors.fromGoal(SupportPlanGoal g) =>
      SupportPlanGoalEditors(
        id: g.id.isEmpty
            ? 'g-${DateTime.now().microsecondsSinceEpoch}-${g.sortOrder}'
            : g.id,
        sortOrder: g.sortOrder,
        ndisGoal: TextEditingController(text: g.ndisGoal),
        strategy: TextEditingController(text: g.strategy),
        measure: TextEditingController(text: g.measure),
        workerInstructions: TextEditingController(text: g.workerInstructions),
      );

  final String id;
  int sortOrder;
  final TextEditingController ndisGoal;
  final TextEditingController strategy;
  final TextEditingController measure;
  final TextEditingController workerInstructions;

  SupportPlanGoal toGoal({required int sortOrder}) => SupportPlanGoal(
        id: id,
        ndisGoal: ndisGoal.text.trim(),
        strategy: strategy.text.trim(),
        measure: measure.text.trim(),
        workerInstructions: workerInstructions.text.trim(),
        sortOrder: sortOrder,
      );

  void dispose() {
    ndisGoal.dispose();
    strategy.dispose();
    measure.dispose();
    workerInstructions.dispose();
  }
}
