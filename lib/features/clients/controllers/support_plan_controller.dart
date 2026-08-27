import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/support_plan_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/support_plan_keys.dart';
import 'support_plan_funding_consent_store.dart';

/// Thin Support Plan form: Care body + Review (status / next review).
class SupportPlanController extends GetxController {
  SupportPlanController({
    required ClientsRepository repository,
    String? clientId,
    String? planId,
    this.clientName,
    this.ndisNumber,
    SupportPlanFundingConsentStore? fundingConsent,
    DocumentPipeline? documentPipeline,
    Future<({String name, List<int> bytes})?> Function()? pickPdfBytes,
  }) : _repository = repository,
       clientId = clientId ?? '',
       _initialPlanId = planId,
       fundingConsent = fundingConsent ??
           SupportPlanFundingConsentStore(
             repository: repository,
             documentPipeline: documentPipeline,
             pickPdfBytes: pickPdfBytes,
           ) {
    if (planId != null && planId.isNotEmpty) {
      this.planId.value = planId;
    }
  }

  final ClientsRepository _repository;

  /// Funding + Consent facts collaborator (D4=B).
  final SupportPlanFundingConsentStore fundingConsent;

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

  /// Soft Activate notice when Consent/SA incomplete (Task 7).
  final activateSoftWarning = RxnString();

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
  final limitationOtherCtrl = TextEditingController();
  final commOtherCtrl = TextEditingController();

  // ── Living ────────────────────────────────────────────────────────────
  final residenceType = SupportPlanKeys.residencePrivateHome.obs;
  final residenceOtherCtrl = TextEditingController();
  final householdMembersCtrl = TextEditingController();
  final informalSupportsCtrl = TextEditingController();

  // ── Goals ─────────────────────────────────────────────────────────────
  final goals = <SupportPlanGoalEditors>[].obs;

  // ── Categories ────────────────────────────────────────────────────────
  final serviceCategories = <String>[].obs;
  final catOtherCtrl = TextEditingController();

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

  /// Combined busy sticky (D7=A).
  bool get isBusy =>
      isSaving.value ||
      fundingConsent.isBusy.value ||
      fundingConsent.isLoading.value;

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
      await fundingConsent.reload(clientId);
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
    limitationOtherCtrl.text = dh.limitationOtherDetail;
    commOtherCtrl.text = dh.commOtherDetail;

    residenceType.value = body.living.residenceType;
    residenceOtherCtrl.text = body.living.residenceOtherDetail;
    householdMembersCtrl.text = body.living.householdMembers;
    informalSupportsCtrl.text = body.living.informalSupports;

    _replaceGoals(body.goals);
    serviceCategories.assignAll(body.serviceCategories);
    catOtherCtrl.text = body.catOtherDetail;

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
      if (key == SupportPlanKeys.limitationOther) {
        limitationOtherCtrl.clear();
      }
    } else {
      functionalLimitations.add(key);
    }
  }

  void toggleCommunication(String key) {
    if (communicationMethods.contains(key)) {
      communicationMethods.remove(key);
      if (key == SupportPlanKeys.commOther) {
        commOtherCtrl.clear();
      }
    } else {
      communicationMethods.add(key);
    }
  }

  void toggleCategory(String key) {
    if (serviceCategories.contains(key)) {
      serviceCategories.remove(key);
      if (key == SupportPlanKeys.catOther) {
        catOtherCtrl.clear();
      }
    } else {
      serviceCategories.add(key);
    }
  }

  void setResidenceType(String value) {
    residenceType.value = value;
    if (value != SupportPlanKeys.residenceOther) {
      residenceOtherCtrl.clear();
    }
  }

  /// Returns a user-facing error when an Other chip/dropdown lacks detail text.
  String? validateOtherDetails() {
    if (functionalLimitations.contains(SupportPlanKeys.limitationOther) &&
        limitationOtherCtrl.text.trim().isEmpty) {
      return 'Specify the functional limitation.';
    }
    if (communicationMethods.contains(SupportPlanKeys.commOther) &&
        commOtherCtrl.text.trim().isEmpty) {
      return 'Specify the communication method.';
    }
    if (serviceCategories.contains(SupportPlanKeys.catOther) &&
        catOtherCtrl.text.trim().isEmpty) {
      return 'Specify the service category.';
    }
    if (residenceType.value == SupportPlanKeys.residenceOther &&
        residenceOtherCtrl.text.trim().isEmpty) {
      return 'Specify the residence type.';
    }
    return null;
  }

  /// Always full nested body (OV1) — never dirty-fields-only.
  SupportPlanBody buildBody() {
    final limitationDetail =
        functionalLimitations.contains(SupportPlanKeys.limitationOther)
            ? limitationOtherCtrl.text.trim()
            : '';
    final commDetail = communicationMethods.contains(SupportPlanKeys.commOther)
        ? commOtherCtrl.text.trim()
        : '';
    final catDetail = serviceCategories.contains(SupportPlanKeys.catOther)
        ? catOtherCtrl.text.trim()
        : '';
    final residenceDetail =
        residenceType.value == SupportPlanKeys.residenceOther
            ? residenceOtherCtrl.text.trim()
            : '';

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
        limitationOtherDetail: limitationDetail,
        commOtherDetail: commDetail,
      ),
      living: LivingSection(
        residenceType: residenceType.value,
        householdMembers: householdMembersCtrl.text.trim(),
        informalSupports: informalSupportsCtrl.text.trim(),
        residenceOtherDetail: residenceDetail,
      ),
      goals: [
        for (var i = 0; i < goals.length; i++) goals[i].toGoal(sortOrder: i),
      ],
      serviceCategories: serviceCategories.toList(growable: false),
      catOtherDetail: catDetail,
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

  /// Reloads the last saved plan. Does not pop a route.
  Future<void> discardDrafts() async {
    errorMessage.value = null;
    activateSoftWarning.value = null;
    await load();
  }

  Future<void> activate() async {
    if (!canActivate) {
      errorMessage.value = 'Set a next review date before activating.';
      return;
    }
    // Status becomes active only after create/PATCH succeeds (via applyLoadedPlan).
    await _persist(activate: true);
  }

  Future<void> _persist({required bool activate}) async {
    if (clientId.isEmpty || isSaving.value) return;
    if (fundingConsent.isBusy.value) return;

    final otherError = validateOtherDetails();
    if (otherError != null) {
      errorMessage.value = otherError;
      return;
    }

    if (fundingConsent.hasHydrated) {
      final fundingError = fundingConsent.validateFunding(
        requirePlanType: activate,
      );
      if (fundingError != null) {
        errorMessage.value = fundingError;
        return;
      }
    }

    isSaving.value = true;
    errorMessage.value = null;
    activateSoftWarning.value = null;
    try {
      if (fundingConsent.hasHydrated) {
        final failed = await fundingConsent.persistFacts(clientId: clientId);
        if (failed.isNotEmpty) {
          errorMessage.value =
              'Could not save funding/consent: ${failed.join(', ')}';
          await fundingConsent.reload(clientId);
          return;
        }
      }

      final body = buildBody();
      // Snapshot prior status for PATCH payload decisions; do not mutate
      // status.value until the network call succeeds (applyLoadedPlan).
      final currentStatus = status.value;

      var id = planId.value;
      if (id == null || id.isEmpty) {
        final createPayload = SupportPlanCreateRequest(body: body).toJson();
        lastSavedPayload = createPayload;
        final created = await _repository.createSupportPlan(
          clientId,
          createPayload,
        );
        id = created.id;
        planId.value = id;
        if (!activate) {
          applyLoadedPlan(created);
          return;
        }
      }

      final String? patchStatus;
      if (activate) {
        patchStatus = SupportPlanKeys.statusActive;
      } else if (currentStatus == SupportPlanKeys.statusDraft) {
        patchStatus = SupportPlanKeys.statusDraft;
      } else {
        patchStatus = null;
      }

      final update = SupportPlanUpdateRequest(
        body: body,
        status: patchStatus,
        nextReviewAt: nextReviewAt.value,
      );
      final payload = update.toJson();
      lastSavedPayload = payload;
      final idToPatch = id;
      if (idToPatch == null || idToPatch.isEmpty) {
        errorMessage.value = 'Missing plan id.';
        return;
      }
      final saved = await _repository.patchSupportPlan(
        clientId,
        idToPatch,
        payload,
      );
      applyLoadedPlan(saved);
      if (activate && fundingConsent.hasHydrated) {
        final missing = <String>[];
        if (!fundingConsent.consentAgreementComplete.value) {
          missing.add('Consent');
        }
        if (!fundingConsent.serviceAgreementComplete.value) {
          missing.add('Service Agreement');
        }
        if (missing.isNotEmpty) {
          activateSoftWarning.value =
              'Plan activated — still missing: ${missing.join(', ')}.';
        }
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (fundingConsent.hasHydrated) {
        await fundingConsent.reload(clientId);
      }
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    fundingConsent.dispose();
    primaryDisabilityCtrl.dispose();
    secondaryConditionsCtrl.dispose();
    functionalImpactCtrl.dispose();
    mobilityNeedsCtrl.dispose();
    medicationScheduleCtrl.dispose();
    gpNameCtrl.dispose();
    gpPhoneCtrl.dispose();
    limitationOtherCtrl.dispose();
    commOtherCtrl.dispose();
    residenceOtherCtrl.dispose();
    catOtherCtrl.dispose();
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
        id:
            g.id.isEmpty
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
