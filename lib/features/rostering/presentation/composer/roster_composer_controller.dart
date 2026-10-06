import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/constants/app_permissions.dart';
import '../../../../app/routes/app_navigator.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/time/tenant_civil_time.dart';
import '../../../../shared/models/profile_photo_models.dart';
import '../../../../shared/utils/name_sort.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/eligibility_incomplete_panel.dart';
import '../../../billing/data/models/billing_models.dart';
import '../../../clients/data/models/client_models.dart';
import '../../../clients/data/repositories/clients_repository.dart';
import '../../../clients/utils/site_geocode_apply.dart';
import '../../../engagements/data/models/engagement_models.dart';
import '../../../engagements/data/repositories/engagements_repository.dart';
import '../../../jobs/data/models/job_models.dart';
import '../../../jobs/utils/recurrence_rrule_builder.dart';
import '../../../jobs/utils/time_window_utils.dart';
import '../../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../../shifts/data/models/shift_models.dart';
import '../../../shifts/data/models/shift_travel_models.dart';
import '../../../shifts/utils/allocation_math.dart';
import '../../../visits/utils/assign_schedule_window.dart';
import '../../data/composer_facade.dart';
import '../../data/composer_models.dart';
import '../../domain/composer_steps.dart';
import '../../domain/composer_validation.dart';
import '../../domain/occurrence_draft.dart';
import '../../domain/repeat_template_payload.dart';
import '../../domain/roster_composer_args.dart';
import '../../domain/support_segment_editor.dart';
import '../shared/assign_context_labels.dart';

/// Unified rostering occurrence composer (stepped wizard).
class RosterComposerController extends GetxController {
  RosterComposerController({
    required ComposerFacade facade,
    required ClientsRepository clientsRepository,
    required SessionService session,
    EngagementsRepository? engagementsRepository,
    RosterComposerArgs? args,
    void Function(String route, dynamic arguments)? onNavigate,
    Future<bool> Function(int nextN)? confirmLargeGroup,
    Future<String?> Function({required String label})? promptAssignOverrideReason,
    Future<bool> Function(int unassignedSlots)? confirmPublishOpenSlots,
    Future<String?> Function({required List<String> reasons})?
    promptBurnOverride,
    Future<String?> Function({
      required List<String> reasons,
      required String title,
    })?
    promptCredentialGateOverride,
  }) : _facade = facade,
       _clients = clientsRepository,
       _session = session,
       _engagements = engagementsRepository,
       _args = args ?? const RosterComposerArgs(),
       _onNavigate = onNavigate,
       _confirmLargeGroup = confirmLargeGroup,
       _promptAssignOverrideReason = promptAssignOverrideReason,
       _confirmPublishOpenSlots = confirmPublishOpenSlots,
       _promptBurnOverride = promptBurnOverride,
       _promptCredentialGateOverride = promptCredentialGateOverride;

  final ComposerFacade _facade;
  final ClientsRepository _clients;
  final SessionService _session;
  final EngagementsRepository? _engagements;
  final RosterComposerArgs _args;
  final void Function(String route, dynamic arguments)? _onNavigate;
  final Future<bool> Function(int nextN)? _confirmLargeGroup;
  final Future<String?> Function({required String label})?
  _promptAssignOverrideReason;
  final Future<bool> Function(int unassignedSlots)? _confirmPublishOpenSlots;
  final Future<String?> Function({required List<String> reasons})?
  _promptBurnOverride;
  final Future<String?> Function({
    required List<String> reasons,
    required String title,
  })?
  _promptCredentialGateOverride;

  final draft = OccurrenceDraft.oneSession().obs;
  final focusSection = ComposerFocusSection.plan.obs;
  final currentStep = ComposerStep.clients.obs;
  final stepError = RxnString();

  final clients = <ClientOut>[].obs;
  final clientSearch = ''.obs;
  final photosByClient = <String, ProfilePhotoOut>{}.obs;
  /// Custom % when equal split is off (participant id → percent).
  final allocationPercents = <String, double>{}.obs;
  final placeOptions = const PlaceOptionsOut().obs;
  final placeOptionsLoading = false.obs;
  final placeOptionsError = RxnString();

  /// Display name for the selected NDIS support item (picker).
  final supportItemName = ''.obs;

  // ── Other place geocode (same modules as client sites) ───────────────────
  final otherLabelCtrl = TextEditingController();
  final otherAddressLine1Ctrl = TextEditingController();
  final otherCityCtrl = TextEditingController();
  final otherStateCtrl = TextEditingController();
  final otherPostalCtrl = TextEditingController();
  final otherLatCtrl = TextEditingController();
  final otherLngCtrl = TextEditingController();
  final otherCountry = 'AU'.obs;
  final otherGeocodeFormatted = RxnString();
  final otherAddressConfirmed = false.obs;
  final otherIsGeocoding = false.obs;
  final otherGeocodeError = RxnString();

  /// Shift participant rows (needed for travel share + segment participant ids).
  final shiftParticipants = <ShiftParticipantOut>[].obs;
  final assignments = <ShiftAssignmentOut>[].obs;

  // ── Forms (A5) ───────────────────────────────────────────────────────────
  final resolvedForms = <ResolvedFormPreviewOut>[].obs;
  final formOverrides = <ShiftFormOverrideOut>[].obs;
  final formTemplates = <FormTemplateOut>[].obs;
  final formsPreviewLoading = false.obs;
  final formsPreviewError = RxnString();
  bool _formsEdited = false;

  // ── Travel (A4 labour shares) ────────────────────────────────────────────
  final travelLabourMinutes = ''.obs;
  final travelMode = TravelApportionmentMode.equal.obs;
  final travelNominatedClientId = RxnString();
  final travelExplicitShares = <String, String>{}.obs;
  final travelClaims = <ShiftTravelOut>[].obs;
  final travelError = RxnString();

  // ── Segments (A3 — after visit exists) ───────────────────────────────────
  final segmentsByVisit = <String, List<SupportSegmentOut>>{}.obs;
  final segmentsError = RxnString();
  final segmentsSaving = false.obs;

  // ── Workers / assign-context (L14) ───────────────────────────────────────
  final engagements = <EngagementOut>[].obs;
  final assignContext = Rxn<AssignContextOut>();
  final assignContextLoading = false.obs;
  final assignContextError = RxnString();
  final assignOverrideReasons = <String, String>{}.obs;
  /// Structured reasons from ``credential_gate_blocked`` / assign gate on save/publish.
  final credentialGateReasons = <String>[].obs;
  bool _workersSectionOpened = false;

  // ── Repeat / A7 ──────────────────────────────────────────────────────────
  final recurrenceRuleId = RxnString();
  final repeatFrequency = RecurrenceFrequency.weekly.obs;
  final repeatWeekdays = <int>{DateTime.monday}.obs;
  final repeatStartDate = DateTime.now().obs;
  final repeatEndDate = Rx<DateTime>(defaultRecurrenceEndDate(DateTime.now()));
  final repeatPublishPolicy = 'published'.obs; // draft | published
  /// Soft suggestions only — maps to rule `contractor_ids` (never auto-assign).
  final preferredContractorIds = <String>[].obs;
  final isGeneratingRepeat = false.obs;
  final generateOutcomeMessage = RxnString();
  final repeatError = RxnString();
  final Map<String, String> _generateIdempotencyKeys = {};

  final isHydrating = true.obs;
  final isSaving = false.obs;
  final isPublishing = false.obs;
  final errorMessage = RxnString();
  final saveErrorDetail = RxnString();
  /// Set only for recoverable network failures (never validation).
  Future<void> Function()? _retryHandler;
  bool get canRetryFailure => _retryHandler != null;

  Future<void> retryLastFailure() async {
    final fn = _retryHandler;
    if (fn != null) await fn();
  }

  /// How many worker slots this occurrence needs (drives picker + claim holes).
  int get workerSlotCount {
    final n =
        draft.value.showsWorkerCount
            ? draft.value.requiredSlots
            : 1;
    return n < 1 ? 1 : n;
  }

  int get assignedWorkerCount => draft.value.contractorIds.length;

  int get unassignedSlotCount {
    final open = workerSlotCount - assignedWorkerCount;
    return open < 0 ? 0 : open;
  }

  bool get hasUnassignedSlots => unassignedSlotCount > 0;

  Timer? _placeDebounce;
  int _placeFetchGen = 0;
  Timer? _formsDebounce;
  int _formsPreviewGen = 0;
  Timer? _assignDebounce;
  int _assignContextGen = 0;

  bool get canManage =>
      _session.hasPermission(AppPermissions.shiftsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  bool get showsAllocation => draft.value.showsAllocation;
  bool get showsWorkerCount => draft.value.showsWorkerCount;
  bool get isGroup => draft.value.preset == ComposerPreset.group;
  bool get hasPersistedShift =>
      draft.value.shiftId != null && draft.value.shiftId!.isNotEmpty;

  List<ClientOut> get filteredClients {
    final q = clientSearch.value.trim().toLowerCase();
    final list = sortedByName(clients, (c) => c.fullName);
    if (q.isEmpty) return list;
    return [for (final c in list) if (c.fullName.toLowerCase().contains(q)) c];
  }

  List<ClientOut> get pickerCandidates {
    final taken = draft.value.participantIds.toSet();
    return [for (final c in filteredClients) if (!taken.contains(c.id)) c];
  }

  /// Type-to-search options for the client autocomplete (empty query → none).
  ///
  /// Dedupes by id, matches name/email/phone, and caps results so identical
  /// display names from seed/test data cannot bury every other client.
  List<ClientOut> clientPickerOptions(String raw, {int limit = 20}) {
    final q = raw.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final taken = draft.value.participantIds.toSet();
    final seen = <String>{};
    final list = <ClientOut>[];
    for (final c in clients) {
      if (taken.contains(c.id) || !seen.add(c.id)) continue;
      if (!_clientMatchesPickerQuery(c, q)) continue;
      list.add(c);
    }
    list.sort((a, b) {
      final byName = a.fullName.toLowerCase().compareTo(
        b.fullName.toLowerCase(),
      );
      if (byName != 0) return byName;
      final ae = (a.email ?? '').toLowerCase();
      final be = (b.email ?? '').toLowerCase();
      final byEmail = ae.compareTo(be);
      if (byEmail != 0) return byEmail;
      return a.id.compareTo(b.id);
    });
    if (list.length <= limit) return list;
    return list.sublist(0, limit);
  }

  /// Subtitle so duplicate full names stay distinguishable in the picker.
  String clientPickerSubtitle(ClientOut client) {
    final parts = <String>[
      if (client.email != null && client.email!.trim().isNotEmpty)
        client.email!.trim(),
      if (client.phone != null && client.phone!.trim().isNotEmpty)
        client.phone!.trim(),
      if (client.primaryDisplayAddress.isNotEmpty) client.primaryDisplayAddress,
    ];
    if (parts.isNotEmpty) return parts.join(' · ');
    final id = client.id;
    return id.length > 8 ? id.substring(0, 8) : id;
  }

  static bool _clientMatchesPickerQuery(ClientOut c, String q) {
    if (c.fullName.toLowerCase().contains(q)) return true;
    final email = c.email?.toLowerCase();
    if (email != null && email.contains(q)) return true;
    final phone = c.phone?.toLowerCase();
    if (phone != null && phone.contains(q)) return true;
    return false;
  }

  String? participantName(String id) {
    for (final c in clients) {
      if (c.id == id) return c.fullName;
    }
    if (_args.participantId == id) return _args.participantName;
    if (_args.clientId == id) return _args.client?.fullName;
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    focusSection.value = _args.focusSection;
    currentStep.value = ComposerStepX.fromFocus(_args.focusSection);
    // Skeleton first paint < 300ms — do not block onInit on network.
    isHydrating.value = true;
    unawaited(_bootstrap());
  }

  bool get isFirstStep => currentStep.value.isFirst;
  bool get isLastStep => currentStep.value.isLast;

  /// Advance wizard; returns false when the current step gate fails.
  Future<bool> goNextStep() async {
    stepError.value = null;
    if (currentStep.value == ComposerStep.place) {
      final prepared = await prepareOtherPlaceForAdvance();
      if (!prepared) return false;
    }
    final errors = _stepGateErrors(currentStep.value);
    if (errors.isNotEmpty) {
      stepError.value = errors.first;
      errorMessage.value = errors.first;
      if (currentStep.value == ComposerStep.place) {
        final travelErr = validateTravelDraft();
        if (travelErr != null) travelError.value = travelErr;
      }
      return false;
    }
    final next = currentStep.value.next;
    if (next == null) return false;
    // Clear banner once the gate passes.
    stepError.value = null;
    errorMessage.value = null;
    travelError.value = null;
    currentStep.value = next;
    _onStepEntered(next);
    return true;
  }

  bool goPreviousStep() {
    stepError.value = null;
    errorMessage.value = null;
    final prev = currentStep.value.previous;
    if (prev == null) return false;
    currentStep.value = prev;
    return true;
  }

  Future<void> goToStep(ComposerStep step) async {
    stepError.value = null;
    // Only allow jumping backward freely; forward jumps must pass gates.
    if (step.index > currentStep.value.index) {
      for (var i = currentStep.value.index; i < step.index; i++) {
        final gate = ComposerStep.values[i];
        if (gate == ComposerStep.place) {
          final prepared = await prepareOtherPlaceForAdvance();
          if (!prepared) {
            currentStep.value = gate;
            return;
          }
        }
        final errors = _stepGateErrors(gate);
        if (errors.isNotEmpty) {
          stepError.value = errors.first;
          errorMessage.value = errors.first;
          currentStep.value = gate;
          return;
        }
      }
    }
    errorMessage.value = null;
    travelError.value = null;
    currentStep.value = step;
    _onStepEntered(step);
  }

  List<String> _stepGateErrors(ComposerStep step) {
    final place = draft.value.place;
    final otherSelected = place is ShiftPlaceLabelled;
    return ComposerValidation.validateStep(
      step,
      draft.value,
      allocationError:
          step == ComposerStep.clients ? validateAllocationDraft() : null,
      travelError:
          step == ComposerStep.place ? validateTravelDraft() : null,
      otherPlaceNeedsLookup:
          step == ComposerStep.place &&
          otherSelected &&
          otherLatCtrl.text.trim().isEmpty,
      otherPlaceNeedsConfirm:
          step == ComposerStep.place &&
          otherSelected &&
          otherLatCtrl.text.trim().isNotEmpty &&
          !otherAddressConfirmed.value,
    );
  }

  String? validateAllocationDraft() {
    return ComposerValidation.validateCustomAllocation(
      draft: draft.value,
      percentByParticipant: Map<String, double>.from(allocationPercents),
    );
  }

  /// Prefer equal-split for N≤1; otherwise honour the toggle.
  bool get _useEqualSplitOnSave {
    if (draft.value.participantIds.length <= 1) return true;
    return draft.value.equalSplit;
  }

  List<ShiftParticipantCreateItem> _participantCreateItems() {
    final equal = _useEqualSplitOnSave;
    return [
      for (final id in draft.value.participantIds)
        ShiftParticipantCreateItem(
          participantId: id,
          allocationStrategy: 'percentage',
          reason: 'roster_composer',
          allocationValue: equal ? null : allocationPercents[id],
        ),
    ];
  }

  List<ShiftParticipantReplaceItem> _participantReplaceItems() {
    final equal = _useEqualSplitOnSave;
    return [
      for (final id in draft.value.participantIds)
        ShiftParticipantReplaceItem(
          participantId: id,
          allocationValue: equal ? null : allocationPercents[id],
        ),
    ];
  }

  void _seedCustomAllocations() {
    final ids = draft.value.participantIds;
    if (ids.isEmpty) {
      allocationPercents.clear();
      return;
    }
    final values = equalPercentageValues(ids.length);
    allocationPercents.assignAll({
      for (var i = 0; i < ids.length; i++) ids[i]: values[i],
    });
  }

  void _onStepEntered(ComposerStep step) {
    switch (step) {
      case ComposerStep.place:
        schedulePlaceOptionsRefresh();
      case ComposerStep.forms:
        unawaited(ensureFormsResolved());
      case ComposerStep.workers:
        onWorkersSectionOpened();
        if (draft.value.repeatEnabled) onRepeatSectionOpened();
      case ComposerStep.clients:
      case ComposerStep.when:
      case ComposerStep.support:
        break;
    }
  }

  @override
  void onClose() {
    _placeDebounce?.cancel();
    _formsDebounce?.cancel();
    _assignDebounce?.cancel();
    _placeFetchGen++;
    _formsPreviewGen++;
    _assignContextGen++;
    otherLabelCtrl.dispose();
    otherAddressLine1Ctrl.dispose();
    otherCityCtrl.dispose();
    otherStateCtrl.dispose();
    otherPostalCtrl.dispose();
    otherLatCtrl.dispose();
    otherLngCtrl.dispose();
    super.onClose();
  }

  List<EngagementOut> get assignableEngagements {
    final seen = <String>{};
    return [
      for (final e in engagements)
        if (e.isActive && seen.add(e.contractorId)) e,
    ];
  }

  bool get hasAssignedVisits => assignments.any((a) => a.status == 'active');

  List<String> get visitIdsWithSegments => [
    for (final a in assignments)
      if (a.status == 'active' && a.visitId.isNotEmpty) a.visitId,
  ];

  Future<void> retryHydrate() => _bootstrap();

  Future<void> _bootstrap() async {
    isHydrating.value = true;
    errorMessage.value = null;
    _retryHandler = null;
    try {
      final seed = _args.composerSeed;
      if (seed != null) {
        await _hydrateFromComposerSeed(seed);
        return;
      }
      final shiftId = _args.shiftId ?? _args.shift?.id;
      if (shiftId != null && shiftId.isNotEmpty) {
        await _hydrateExisting(shiftId, seed: _args.shift);
        return;
      }
      await _greenfieldWave1();
    } on _PublishedBounce {
      // Navigation already requested.
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      _retryHandler = retryHydrate;
    } catch (e) {
      errorMessage.value = e.toString();
      _retryHandler = retryHydrate;
    } finally {
      isHydrating.value = false;
    }
  }

  /// Apply a full [ComposerShiftOut] without a second hydrate RTT (copy-tile).
  Future<void> _hydrateFromComposerSeed(ComposerShiftOut composer) async {
    if (composer.shift.status != 'draft') {
      _bounceToDetail(composer.shift);
      throw _PublishedBounce();
    }
    _finishComposerHydrate(composer);
  }

  Future<void> _hydrateExisting(String shiftId, {ShiftOut? seed}) async {
    if (seed != null && seed.status != 'draft') {
      _bounceToDetail(seed);
      throw _PublishedBounce();
    }
    final composer = await _facade.getComposer(shiftId);
    if (composer.shift.status != 'draft') {
      _bounceToDetail(composer.shift);
      throw _PublishedBounce();
    }
    _finishComposerHydrate(composer);
  }

  void _finishComposerHydrate(ComposerShiftOut composer) {
    final ruleId =
        composer.shift.recurrenceRuleId ?? _args.recurrenceRuleId;
    final repeatOn =
        _args.repeatEnabled || (ruleId != null && ruleId.isNotEmpty);
    if (ruleId != null && ruleId.isNotEmpty) {
      recurrenceRuleId.value = ruleId;
    }
    _applyComposerSeed(composer, repeatEnabled: repeatOn);
    if (repeatOn) _seedRepeatDefaults();
    unawaited(() async {
      try {
        clients.assignAll(await _clients.listClients());
      } catch (_) {}
    }());
    unawaited(_loadFormTemplates());
    unawaited(ensureParticipantPhotos());
    schedulePlaceOptionsRefresh();
  }

  void _applyComposerSeed(
    ComposerShiftOut composer, {
    bool repeatEnabled = false,
  }) {
    draft.value = _draftFromShift(
      composer.shift,
      preset: _inferPreset(composer.shift),
      repeatEnabled: repeatEnabled,
    );
    shiftParticipants.assignAll(composer.shift.participants);
    assignments.assignAll(composer.shift.assignments);
    // Seed Forms from hydrate — do not call preview until user edits.
    resolvedForms.assignAll(composer.resolvedFormsPreview);
    formOverrides.assignAll(composer.formOverrides);
    _formsEdited = false;
    travelClaims.assignAll(composer.shift.travelClaims);
    _seedTravelFromClaims(composer.shift.travelClaims);
    final segments = <String, List<SupportSegmentOut>>{};
    for (final entry in composer.segmentsByVisit.entries) {
      segments[entry.key] = [
        for (final row in entry.value) SupportSegmentOut.fromJson(row),
      ];
    }
    segmentsByVisit.assignAll(segments);
  }

  Future<void> _greenfieldWave1() async {
    final preset = _args.preset;
    final repeat = _args.repeatEnabled;
    final start = DateTime.now().add(const Duration(hours: 1));
    final end = start.add(const Duration(hours: 2));

    if (preset == ComposerPreset.group) {
      draft.value = OccurrenceDraft.group(
        jobId: _args.jobId,
        participantIds: [
          if (_args.participantId != null) _args.participantId!,
        ],
        scheduledStart: start,
        scheduledEnd: end,
      );
    } else {
      draft.value = OccurrenceDraft.oneSession(
        clientId: _args.clientId ?? _args.client?.id,
        scheduledStart: start,
        scheduledEnd: end,
        repeatEnabled: repeat,
      ).copyWith(jobId: _args.jobId);
    }

    final clientId = draft.value.clientId ?? _args.participantId;
    final jobId = _args.jobId;

    // Parallel wave 1 per greenfield call graph.
    final futures = <Future<void>>[
      _clients.listClients().then(clients.assignAll),
      _loadFormTemplates(),
    ];

    if (clientId != null && clientId.isNotEmpty) {
      futures.add(_seedClientAndPlace(clientId));
      if (preset == ComposerPreset.oneSession) {
        futures.add(_ensureStandingJob(clientId));
      }
    }

    if (jobId != null && jobId.isNotEmpty) {
      futures.add(_seedFromJob(jobId));
    }

    await Future.wait(futures);
    if (repeat) {
      recurrenceRuleId.value = _args.recurrenceRuleId;
      _seedRepeatDefaults();
    }
    schedulePlaceOptionsRefresh();
  }

  Future<void> _seedClientAndPlace(String clientId) async {
    try {
      final results = await Future.wait([
        _args.client != null && _args.client!.id == clientId
            ? Future.value(_args.client!)
            : _clients.getClient(clientId),
        _clients.listSites(clientId),
      ]);
      final client = results[0] as ClientOut;
      final sites = results[1] as List<ClientSiteOut>;
      if (!clients.any((c) => c.id == client.id)) {
        clients.add(client);
      }
      ClientSiteOut? primary;
      for (final s in sites) {
        if (s.isPrimary) {
          primary = s;
          break;
        }
      }
      primary ??= sites.isEmpty ? null : sites.first;
      draft.value = draft.value.copyWith(
        clientId: clientId,
        place:
            draft.value.place ??
            (primary != null ? ShiftPlaceIn.clientSite(primary.id) : null),
        participantIds:
            draft.value.participantIds.isEmpty
                ? [clientId]
                : draft.value.participantIds,
      );
    } catch (_) {
      // Non-fatal for wave 1 — user can pick client/place manually.
    }
  }

  Future<void> _ensureStandingJob(String clientId) async {
    try {
      final job = await _facade.jobs.ensureOngoingSupport(clientId);
      draft.value = draft.value.copyWith(
        jobId: job.id,
        supportItemCode: draft.value.supportItemCode ?? job.supportItemCode,
      );
      if ((supportItemName.value.isEmpty) &&
          (job.supportItemName?.trim().isNotEmpty ?? false)) {
        supportItemName.value = job.supportItemName!.trim();
      }
    } catch (_) {
      // Save will retry job ensure.
    }
  }

  Future<void> _seedFromJob(String jobId) async {
    try {
      final job = await _facade.jobs.getJob(jobId);
      draft.value = draft.value.copyWith(
        jobId: job.id,
        clientId: draft.value.clientId ?? job.clientId,
        supportItemCode: draft.value.supportItemCode ?? job.supportItemCode,
        place:
            draft.value.place ??
            (job.clientSiteId != null
                ? ShiftPlaceIn.clientSite(job.clientSiteId!)
                : job.branchId != null
                ? ShiftPlaceIn.branch(job.branchId!)
                : null),
      );
      if ((supportItemName.value.isEmpty) &&
          (job.supportItemName?.trim().isNotEmpty ?? false)) {
        supportItemName.value = job.supportItemName!.trim();
      }
    } catch (_) {}
  }

  ComposerPreset _inferPreset(ShiftOut shift) {
    if (_args.preset == ComposerPreset.group) return ComposerPreset.group;
    if (shift.participants.length > 1) return ComposerPreset.group;
    return _args.preset;
  }

  OccurrenceDraft _draftFromShift(
    ShiftOut shift, {
    required ComposerPreset preset,
    bool repeatEnabled = false,
  }) {
    return OccurrenceDraft(
      preset: preset,
      shiftId: shift.id,
      jobId: shift.jobId,
      clientId: shift.clientId,
      scheduledStart: shift.scheduledStart.toLocal(),
      scheduledEnd: shift.scheduledEnd.toLocal(),
      place: _placeFromShift(shift),
      participantIds: [
        for (final p in shift.participants) p.participantId,
      ],
      equalSplit: true,
      workerCount: shift.workerCount,
      requiredSlots: shift.requiredSlots,
      supportItemCode: null,
      taskTemplate: shift.taskTemplate,
      segmentTemplate: shift.segmentTemplate,
      contractorIds: [for (final a in shift.assignments) a.contractorId],
      repeatEnabled: repeatEnabled,
      status: shift.status,
    );
  }

  ShiftPlaceIn? _placeFromShift(ShiftOut shift) {
    if (shift.placeBranchId != null && shift.placeBranchId!.isNotEmpty) {
      return ShiftPlaceIn.branch(shift.placeBranchId!);
    }
    if (shift.placeClientSiteId != null &&
        shift.placeClientSiteId!.isNotEmpty) {
      return ShiftPlaceIn.clientSite(shift.placeClientSiteId!);
    }
    final label = shift.placeLabel?.trim();
    if (label != null && label.isNotEmpty) {
      final lat = shift.placeLatitude;
      final lng = shift.placeLongitude;
      final postal = (shift.postalCode ?? '').trim();
      if (lat != null && lng != null && postal.isNotEmpty) {
        return ShiftPlaceIn.labelled(
          label: label,
          latitude: lat,
          longitude: lng,
          postalCode: postal,
        );
      }
    }
    return null;
  }

  void _bounceToDetail(ShiftOut shift) {
    _navigate(AppRoutes.staffShiftDetail, shift);
  }

  void setPreset(ComposerPreset preset) {
    if (draft.value.preset == preset) return;
    final current = draft.value;
    // Standing vs program jobs must not cross presets (Bugbot: host-style group).
    // Clear jobId so create re-resolves; persisted shifts keep their server job.
    if (preset == ComposerPreset.oneSession) {
      final clientId =
          current.clientId ??
          (current.participantIds.isNotEmpty
              ? current.participantIds.first
              : null);
      draft.value = current.copyWith(
        preset: preset,
        clearJobId: true,
        clientId: clientId,
        participantIds: clientId != null ? [clientId] : const [],
        workerCount: 1,
        requiredSlots: 1,
        equalSplit: true,
      );
    } else {
      draft.value = current.copyWith(preset: preset, clearJobId: true);
    }
    schedulePlaceOptionsRefresh();
  }

  void setRepeatEnabled(bool enabled) {
    draft.value = draft.value.copyWith(repeatEnabled: enabled);
    if (enabled) {
      _seedRepeatDefaults();
      unawaited(_ensureEngagementsLoaded());
    }
  }

  void onRepeatSectionOpened() {
    if (!draft.value.repeatEnabled) return;
    _seedRepeatDefaults();
    unawaited(_ensureEngagementsLoaded());
  }

  void _seedRepeatDefaults() {
    final start = draft.value.scheduledStart;
    if (start != null) {
      final civil = DateTime(start.year, start.month, start.day);
      if (repeatStartDate.value.isBefore(civil) ||
          recurrenceRuleId.value == null) {
        repeatStartDate.value = civil;
        repeatWeekdays
          ..clear()
          ..add(civil.weekday);
      }
      if (repeatEndDate.value.isBefore(repeatStartDate.value)) {
        repeatEndDate.value = defaultRecurrenceEndDate(repeatStartDate.value);
      }
    }
    if (preferredContractorIds.isEmpty &&
        draft.value.contractorIds.isNotEmpty) {
      preferredContractorIds.assignAll(
        draft.value.contractorIds.take(draft.value.requiredSlots),
      );
    }
    if (_args.recurrenceRuleId != null &&
        _args.recurrenceRuleId!.isNotEmpty &&
        recurrenceRuleId.value == null) {
      recurrenceRuleId.value = _args.recurrenceRuleId;
    }
  }

  bool get repeatRequiresWeekdays =>
      repeatFrequency.value == RecurrenceFrequency.weekly ||
      repeatFrequency.value == RecurrenceFrequency.fortnightly;

  void setRepeatFrequency(RecurrenceFrequency value) {
    repeatFrequency.value = value;
  }

  void toggleRepeatWeekday(int day) {
    if (repeatWeekdays.contains(day)) {
      repeatWeekdays.remove(day);
    } else {
      repeatWeekdays.add(day);
    }
  }

  void setRepeatStartDate(DateTime date) {
    repeatStartDate.value = DateTime(date.year, date.month, date.day);
    if (repeatEndDate.value.isBefore(repeatStartDate.value)) {
      repeatEndDate.value = defaultRecurrenceEndDate(repeatStartDate.value);
    }
  }

  void setRepeatEndDate(DateTime date) {
    repeatEndDate.value = DateTime(date.year, date.month, date.day);
  }

  void setRepeatPublishPolicy(String policy) {
    if (policy == 'draft' || policy == 'published') {
      repeatPublishPolicy.value = policy;
    }
  }

  void setPreferredContractorAt(int index, String? contractorId) {
    final slots = List<String?>.generate(
      draft.value.requiredSlots,
      (i) => i < preferredContractorIds.length ? preferredContractorIds[i] : null,
    );
    while (slots.length <= index) {
      slots.add(null);
    }
    if (contractorId != null &&
        slots.asMap().entries.any(
          (e) => e.key != index && e.value == contractorId,
        )) {
      repeatError.value = 'That worker is already suggested in another slot.';
      return;
    }
    slots[index] = contractorId;
    preferredContractorIds.assignAll([
      for (final id in slots)
        if (id != null && id.isNotEmpty) id,
    ]);
    if (repeatError.value?.contains('already suggested') == true) {
      repeatError.value = null;
    }
  }

  /// Build create body for tests / save (includes soft preferred contractor_ids).
  RecurrenceRuleCreateRequest buildRepeatCreateRequest() {
    return RepeatTemplatePayload.buildCreate(
      draft: draft.value,
      frequency: repeatFrequency.value,
      weekdays: repeatWeekdays.toSet(),
      startDate: repeatStartDate.value,
      endDate: repeatEndDate.value,
      publishPolicy: repeatPublishPolicy.value,
      preferredContractorIds: preferredContractorIds.toList(growable: false),
      formOverrides: formOverrides.toList(growable: false),
    );
  }

  RecurrenceRulePatchRequest buildRepeatPatchRequest() {
    final window = RepeatTemplatePayload.windowFromSchedule(draft.value);
    return RepeatTemplatePayload.buildPatch(
      draft: draft.value,
      publishPolicy: repeatPublishPolicy.value,
      preferredContractorIds: preferredContractorIds.toList(growable: false),
      formOverrides: formOverrides.toList(growable: false),
      timeWindows: window == null ? null : [window],
    );
  }

  String? _validateRepeatFields() {
    if (repeatRequiresWeekdays && repeatWeekdays.isEmpty) {
      return 'Select at least one weekday.';
    }
    if (repeatEndDate.value.isBefore(repeatStartDate.value)) {
      return 'End date must not be before the start date.';
    }
    final window = RepeatTemplatePayload.windowFromSchedule(draft.value);
    if (window == null) {
      return 'Set start and end times before saving a repeat pattern.';
    }
    final windowError = validateVisitWindows([window]);
    if (windowError != null) return windowError;
    if (preferredContractorIds.length > draft.value.requiredSlots) {
      return 'Suggested workers cannot exceed required slots.';
    }
    return null;
  }

  /// Create or patch the A7 rule from the current occurrence draft.
  Future<bool> saveRepeatRule() async {
    if (!canManage || !draft.value.repeatEnabled) return false;
    repeatError.value = null;
    final validation = _validateRepeatFields();
    if (validation != null) {
      repeatError.value = validation;
      errorMessage.value = validation;
      return false;
    }
    if (repeatPublishPolicy.value == 'published' &&
        !draft.value.hasSupportAnchor) {
      const msg =
          'Choose a support item before generating open (published) shifts.';
      repeatError.value = msg;
      errorMessage.value = msg;
      return false;
    }

    try {
      try {
        compileRecurrenceRrule(
          frequency: repeatFrequency.value,
          weekdays: repeatWeekdays.toSet(),
        );
      } on ArgumentError {
        repeatError.value = 'Select at least one weekday.';
        return false;
      }

      final jobId = await _resolveJobIdForCreate();
      await _ensureJobSupportItem(jobId);
      final existingId = recurrenceRuleId.value;
      if (existingId != null && existingId.isNotEmpty) {
        final patched = await _facade.patchRecurrenceRule(
          jobId: jobId,
          ruleId: existingId,
          body: buildRepeatPatchRequest(),
        );
        recurrenceRuleId.value = patched.id;
        _applyRuleWarnings(patched);
      } else {
        final created = await _facade.createRecurrenceRule(
          jobId,
          buildRepeatCreateRequest(),
        );
        recurrenceRuleId.value = created.id;
        _applyRuleWarnings(created);
      }
      return true;
    } on AppFailure catch (e) {
      final msg = _mapRepeatError(e);
      repeatError.value = msg;
      errorMessage.value = msg;
      return false;
    } catch (e) {
      repeatError.value = e.toString();
      errorMessage.value = e.toString();
      return false;
    }
  }

  Future<void> _ensureJobSupportItem(String jobId) async {
    final code = draft.value.supportItemCode?.trim();
    if (code == null || code.isEmpty) return;
    final name = supportItemName.value.trim();
    try {
      await _facade.jobs.patchJobSupportItem(
        jobId,
        SupportItemPatch(
          supportItemCode: code,
          supportItemName: name.isEmpty ? null : name,
        ),
      );
    } catch (_) {
      // Non-fatal — participant overrides on the rule still carry the code.
    }
  }

  String _mapRepeatError(AppFailure e) {
    switch (e.code) {
      case 'support_item_required':
        return 'Choose a support item before generating open (published) shifts.';
      default:
        return e.message;
    }
  }

  void _applyRuleWarnings(RecurrenceRuleOut rule) {
    if (rule.warnings.contains('worker_count_slots_mismatch') &&
        !Get.testMode) {
      AppToast.info(
        'Workers vs slots',
        'Worker count and required slots differ — open holes stay claimable.',
      );
    }
  }

  /// Non-blocking horizon generate — never sets [isSaving] / blocks the shell.
  Future<void> generateRepeatHorizon() async {
    if (!canManage || isGeneratingRepeat.value) return;

    // Flip progress immediately (<300ms) without locking Save draft.
    isGeneratingRepeat.value = true;
    generateOutcomeMessage.value = null;
    repeatError.value = null;
    try {
      var ruleId = recurrenceRuleId.value;
      var jobId = draft.value.jobId;
      if (ruleId == null || ruleId.isEmpty || jobId == null || jobId.isEmpty) {
        final saved = await saveRepeatRule();
        if (!saved || recurrenceRuleId.value == null) return;
        ruleId = recurrenceRuleId.value;
        jobId = draft.value.jobId;
      }
      if (jobId == null || ruleId == null) return;

      final tz = await _resolveTenantTimezone();
      final horizon = tenantHorizonWindowUtc(DateTime.now().toUtc(), tz);
      final key =
          '$ruleId|${horizon.from.toIso8601String()}|'
          '${horizon.to.toIso8601String()}';
      final idemKey = _generateIdempotencyKeys.putIfAbsent(
        key,
        () =>
            'fe-composer-gen-$ruleId-'
            '${DateTime.now().microsecondsSinceEpoch}',
      );
      final result = await _facade.generateVisits(
        jobId: jobId,
        ruleId: ruleId,
        body: GenerateVisitsRequest(from: horizon.from, to: horizon.to),
        idempotencyKey: idemKey,
      );
      final n = result.createdShiftIds.length;
      final policy = repeatPublishPolicy.value;
      if (policy == 'draft') {
        generateOutcomeMessage.value =
            n == 0
                ? 'No new draft shifts in the next 14 days.'
                : 'Created $n draft shift${n == 1 ? '' : 's'} '
                    '(not on the claim board).';
      } else {
        generateOutcomeMessage.value =
            n == 0
                ? 'No new open shifts in the next 14 days.'
                : 'Created $n open shift${n == 1 ? '' : 's'} '
                    'with holes for claim.';
      }
      if (result.skipped.isNotEmpty) {
        generateOutcomeMessage.value =
            '${generateOutcomeMessage.value} '
            'Skipped ${result.skipped.length}.';
      }
    } on AppFailure catch (e) {
      repeatError.value = _mapRepeatError(e);
      generateOutcomeMessage.value = null;
    } catch (e) {
      repeatError.value = e.toString();
      generateOutcomeMessage.value = null;
    } finally {
      isGeneratingRepeat.value = false;
    }
  }

  /// This-and-future → backend split-from (copies full A7 template).
  Future<bool> splitThisAndFuture() async {
    if (!canManage) return false;
    final ruleId = recurrenceRuleId.value ?? _args.recurrenceRuleId;
    final jobId = draft.value.jobId;
    if (ruleId == null ||
        ruleId.isEmpty ||
        jobId == null ||
        jobId.isEmpty) {
      repeatError.value = 'Save a repeat pattern before editing this and future.';
      return false;
    }
    final window = RepeatTemplatePayload.windowFromSchedule(draft.value);
    if (window == null) {
      repeatError.value = 'Set start and end times first.';
      return false;
    }
    repeatError.value = null;
    try {
      final tz = await _resolveTenantTimezone();
      final start = draft.value.scheduledStart!;
      final civil = DateTime(start.year, start.month, start.day);
      final horizon = tenantHorizonWindowFromCivilDate(civil, tz);
      final out = await _facade.splitRecurrenceFrom(
        jobId: jobId,
        ruleId: ruleId,
        body: SplitRecurrenceRequest(
          fromDate: civil,
          timeWindows: [window],
          contractorIds: preferredContractorIds.toList(growable: false),
          requiredSlots: draft.value.requiredSlots,
          horizonFrom: horizon.from,
          horizonTo: horizon.to,
        ),
      );
      recurrenceRuleId.value = out.newRule.id;
      repeatPublishPolicy.value = out.newRule.publishPolicy;
      preferredContractorIds.assignAll(out.newRule.contractorIds);
      final n = out.horizon.createdShiftIds.length;
      generateOutcomeMessage.value =
          'Split complete. New pattern from ${formatAppDateCivil(civil)}; '
          '$n shift${n == 1 ? '' : 's'} in horizon.';
      return true;
    } on AppFailure catch (e) {
      repeatError.value = e.message;
      return false;
    } catch (e) {
      repeatError.value = e.toString();
      return false;
    }
  }

  String formatAppDateCivil(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void setSchedule({DateTime? start, DateTime? end}) {
    draft.value = draft.value.copyWith(
      scheduledStart: start ?? draft.value.scheduledStart,
      scheduledEnd: end ?? draft.value.scheduledEnd,
    );
    if (_workersSectionOpened) {
      scheduleAssignContextRefresh();
    }
  }

  void setPlace(ShiftPlaceIn? place) {
    draft.value =
        place == null
            ? draft.value.copyWith(clearPlace: true)
            : draft.value.copyWith(place: place);
    if (place is! ShiftPlaceLabelled) {
      otherAddressConfirmed.value = false;
      otherGeocodeFormatted.value = null;
      otherGeocodeError.value = null;
    }
  }

  void setSupportItemCode(String? code) {
    draft.value =
        (code == null || code.isEmpty)
            ? draft.value.copyWith(clearSupportItemCode: true)
            : draft.value.copyWith(supportItemCode: code);
    if (code == null || code.isEmpty) supportItemName.value = '';
  }

  void setSupportItem({required String? code, required String? name}) {
    supportItemName.value = name?.trim() ?? '';
    setSupportItemCode(code?.trim().isEmpty == true ? null : code?.trim());
  }

  /// Replace visit task checklist (A8 Support step). One title → one task.
  void setTaskTitles(Iterable<String> titles) {
    final cleaned = <String>[
      for (final t in titles)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    draft.value = draft.value.copyWith(
      taskTemplate: [
        for (var i = 0; i < cleaned.length; i++)
          TaskTemplateItem(title: cleaned[i], sortOrder: i),
      ],
    );
  }

  void setTaskTemplate(List<TaskTemplateItem> tasks) {
    draft.value = draft.value.copyWith(
      taskTemplate: [
        for (var i = 0; i < tasks.length; i++)
          TaskTemplateItem(
            title: tasks[i].title.trim(),
            sortOrder: i,
            supportItemCode: tasks[i].supportItemCode,
          ),
      ].where((t) => t.title.isNotEmpty).toList(growable: false),
    );
  }

  /// Replace planned support windows on the draft (`segment_template` offsets).
  /// Persisted on the next create/patch Save draft.
  void setSegmentTemplate(List<SegmentTemplateItem> items) {
    draft.value = draft.value.copyWith(
      segmentTemplate: [
        for (var i = 0; i < items.length; i++)
          SegmentTemplateItem(
            participantId: items[i].participantId.trim(),
            anchorSupportItemCode: items[i].anchorSupportItemCode.trim(),
            kind: items[i].kind,
            offsetStartMinutes: items[i].offsetStartMinutes,
            offsetEndMinutes: items[i].offsetEndMinutes,
            groupSize: items[i].groupSize,
            notes: items[i].notes,
            sortOrder: i,
          ),
      ],
    );
    segmentsError.value = null;
  }

  /// Clear planned windows so assign uses Mode A.
  void clearSegmentTemplate() {
    draft.value = draft.value.copyWith(segmentTemplate: const []);
    segmentsError.value = null;
  }

  void addTaskTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    setTaskTitles([
      for (final t in draft.value.taskTemplate) t.title,
      trimmed,
    ]);
  }

  void removeTaskAt(int index) {
    final current = draft.value.taskTemplate;
    if (index < 0 || index >= current.length) return;
    setTaskTitles([
      for (var i = 0; i < current.length; i++)
        if (i != index) current[i].title,
    ]);
  }

  void setWorkerCount(int n) {
    // Keep planned workers and claim holes aligned — fill on Workers step.
    setWorkerSlots(n);
  }

  void setRequiredSlots(int n) {
    setWorkerSlots(n);
  }

  /// Single control: how many worker slots (assigned now + open for claim).
  void setWorkerSlots(int n) {
    final slots = n < 1 ? 1 : n;
    final contractors =
        draft.value.contractorIds.length > slots
            ? draft.value.contractorIds.take(slots).toList()
            : draft.value.contractorIds;
    draft.value = draft.value.copyWith(
      workerCount: slots,
      requiredSlots: slots,
      contractorIds: contractors,
    );
    if (preferredContractorIds.length > slots) {
      preferredContractorIds.assignAll(preferredContractorIds.take(slots));
    }
  }

  void setEqualSplit(bool equal) {
    draft.value = draft.value.copyWith(equalSplit: equal);
    if (equal) {
      allocationPercents.clear();
    } else {
      _seedCustomAllocations();
    }
  }

  void setAllocationPercent(String participantId, double? percent) {
    final next = Map<String, double>.from(allocationPercents);
    if (percent == null) {
      next.remove(participantId);
    } else {
      next[participantId] = percent;
    }
    allocationPercents.assignAll(next);
    if (draft.value.equalSplit) {
      draft.value = draft.value.copyWith(equalSplit: false);
    }
  }

  void toggleContractor(String contractorId) {
    final ids = [...draft.value.contractorIds];
    if (ids.contains(contractorId)) {
      ids.remove(contractorId);
    } else {
      ids.add(contractorId);
    }
    draft.value = draft.value.copyWith(contractorIds: ids);
  }

  Future<bool> addParticipant(ClientOut client) async {
    if (!clients.any((c) => c.id == client.id)) clients.add(client);
    unawaited(ensureClientPhoto(client.id));

    // One session: replace, never accumulate.
    if (!isGroup) {
      draft.value = draft.value.copyWith(
        participantIds: [client.id],
        clientId: client.id,
        equalSplit: true,
      );
      allocationPercents.clear();
      schedulePlaceOptionsRefresh();
      return true;
    }

    if (draft.value.participantIds.contains(client.id)) return false;
    final nextN = draft.value.participantIds.length + 1;
    if (atHardCap(draft.value.participantIds.length)) {
      errorMessage.value = ComposerValidation.participantsCap;
      return false;
    }
    if (needsLargeGroupConfirm(nextN)) {
      final ok = await _askLargeGroupConfirm(nextN);
      if (!ok) return false;
    }
    final ids = [...draft.value.participantIds, client.id];
    draft.value = draft.value.copyWith(
      participantIds: ids,
      clientId: draft.value.clientId ?? client.id,
    );
    if (!draft.value.equalSplit) _seedCustomAllocations();
    schedulePlaceOptionsRefresh();
    return true;
  }

  void removeParticipant(String participantId) {
    final ids = [
      for (final id in draft.value.participantIds)
        if (id != participantId) id,
    ];
    final nextClientId = ids.isEmpty ? draft.value.clientId : ids.first;
    draft.value = draft.value.copyWith(
      participantIds: ids,
      clientId: nextClientId,
    );
    if (ids.isEmpty && !isGroup) {
      draft.value = OccurrenceDraft(
        preset: ComposerPreset.oneSession,
        shiftId: draft.value.shiftId,
        jobId: draft.value.jobId,
        scheduledStart: draft.value.scheduledStart,
        scheduledEnd: draft.value.scheduledEnd,
        place: draft.value.place,
        supportItemCode: draft.value.supportItemCode,
        taskTemplate: draft.value.taskTemplate,
        repeatEnabled: draft.value.repeatEnabled,
      );
      allocationPercents.clear();
    } else if (!draft.value.equalSplit) {
      _seedCustomAllocations();
    }
    schedulePlaceOptionsRefresh();
  }

  ProfilePhotoOut? photoFor(String clientId) => photosByClient[clientId];

  Future<void> ensureClientPhoto(String clientId) async {
    if (photosByClient.containsKey(clientId)) return;
    try {
      photosByClient[clientId] = await _clients.getClientProfilePhoto(clientId);
    } catch (_) {
      photosByClient[clientId] = const ProfilePhotoOut();
    }
  }

  Future<void> ensureParticipantPhotos() async {
    await Future.wait([
      for (final id in draft.value.participantIds) ensureClientPhoto(id),
    ]);
  }

  Future<bool> _askLargeGroupConfirm(int nextN) async {
    if (_confirmLargeGroup != null) return _confirmLargeGroup(nextN);
    if (Get.testMode) return true;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Large group'),
        content: Text('Large group ($nextN). Continue?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void schedulePlaceOptionsRefresh() {
    _placeDebounce?.cancel();
    _placeDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(loadPlaceOptions());
    });
  }

  Future<void> loadPlaceOptions() async {
    final gen = ++_placeFetchGen;
    placeOptionsLoading.value = true;
    placeOptionsError.value = null;
    try {
      final result = await _facade.fetchPlaceOptions(
        participantIds: draft.value.participantIds,
      );
      if (gen != _placeFetchGen) return;
      placeOptions.value = result;
    } on AppFailure catch (e) {
      if (gen != _placeFetchGen) return;
      placeOptionsError.value = e.message;
    } catch (e) {
      if (gen != _placeFetchGen) return;
      placeOptionsError.value = e.toString();
    } finally {
      if (gen == _placeFetchGen) placeOptionsLoading.value = false;
    }
  }

  Future<void> retryPlaceOptions() => loadPlaceOptions();

  // ── Forms ────────────────────────────────────────────────────────────────

  Future<void> _loadFormTemplates() async {
    try {
      formTemplates.assignAll(
        await _facade.jobs.listFormTemplates(tenantLevel: true),
      );
    } catch (_) {
      // Catalog is optional for composer — overrides can still be seeded.
    }
  }

  /// Add override chip (never marks catalog as required via addFormCatalog).
  void addFormOverride(FormTemplateOut template, {bool isRequired = true}) {
    final existing = [
      for (final o in formOverrides)
        if (o.formTemplateId != template.id) o,
    ];
    existing.add(
      ShiftFormOverrideOut(
        formTemplateId: template.id,
        action: 'add',
        isRequired: isRequired,
        name: template.name,
        isActive: template.isActive,
      ),
    );
    formOverrides.assignAll(existing);
    // Show immediately — do not wait for preview RTT / jobId.
    if (!resolvedForms.any((f) => f.formTemplateId == template.id)) {
      resolvedForms.add(
        ResolvedFormPreviewOut(
          formTemplateId: template.id,
          name: template.name,
          isRequired: isRequired,
          source: 'override',
        ),
      );
    }
    _onFormsEdited();
  }

  /// Resolve inherited + override forms when entering the Forms step.
  Future<void> ensureFormsResolved() async {
    final jobId = draft.value.jobId;
    if (jobId == null || jobId.isEmpty) {
      // Greenfield without job yet — keep local override chips visible.
      _syncLocalAddOverrideChips();
      return;
    }
    await _previewFormsAndMaybePersist(force: true);
  }

  void _syncLocalAddOverrideChips() {
    final resolvedIds = {for (final f in resolvedForms) f.formTemplateId};
    for (final o in formOverrides) {
      if (o.action != 'add' || resolvedIds.contains(o.formTemplateId)) {
        continue;
      }
      resolvedForms.add(
        ResolvedFormPreviewOut(
          formTemplateId: o.formTemplateId,
          name: o.name,
          isRequired: o.isRequired,
          source: 'override',
        ),
      );
    }
  }

  void removeFormOverride(String formTemplateId) {
    final existing = [
      for (final o in formOverrides)
        if (o.formTemplateId != formTemplateId) o,
    ];
    // If inherited/org form is currently resolved, mark a remove override.
    final wasResolved = resolvedForms.any(
      (f) => f.formTemplateId == formTemplateId && f.source != 'override',
    );
    if (wasResolved) {
      final name = resolvedForms
          .firstWhere((f) => f.formTemplateId == formTemplateId)
          .name;
      existing.add(
        ShiftFormOverrideOut(
          formTemplateId: formTemplateId,
          action: 'remove',
          isRequired: false,
          name: name,
          isActive: true,
        ),
      );
    }
    formOverrides.assignAll(existing);
    // Drop from resolved chips immediately for UX; preview will refresh.
    resolvedForms.assignAll([
      for (final f in resolvedForms)
        if (f.formTemplateId != formTemplateId) f,
    ]);
    _onFormsEdited();
  }

  void clearFormOverride(String formTemplateId) {
    formOverrides.assignAll([
      for (final o in formOverrides)
        if (o.formTemplateId != formTemplateId) o,
    ]);
    _onFormsEdited();
  }

  void _onFormsEdited() {
    _formsEdited = true;
    _formsDebounce?.cancel();
    _formsDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_previewFormsAndMaybePersist());
    });
  }

  Future<void> _previewFormsAndMaybePersist({bool force = false}) async {
    final jobId = draft.value.jobId;
    if (jobId == null || jobId.isEmpty) {
      _syncLocalAddOverrideChips();
      return;
    }
    if (!_formsEdited && !force) return;

    final gen = ++_formsPreviewGen;
    formsPreviewLoading.value = true;
    formsPreviewError.value = null;
    try {
      final preview = await _facade.previewForms(
        FormPreviewRequirementsRequest(
          jobId: jobId,
          shiftId: draft.value.shiftId,
          participantIds: draft.value.participantIds,
          overrides: [
            for (final o in formOverrides)
              FormPreviewOverrideIn(
                formTemplateId: o.formTemplateId,
                action: o.action,
                isRequired: o.isRequired,
              ),
          ],
        ),
      );
      if (gen != _formsPreviewGen) return;
      resolvedForms.assignAll(preview);
      _syncLocalAddOverrideChips();

      if (hasPersistedShift) {
        await _facade.putFormOverrides(
          draft.value.shiftId!,
          formOverrides.toList(growable: false),
        );
      }
    } on AppFailure catch (e) {
      if (gen != _formsPreviewGen) return;
      formsPreviewError.value = e.message;
      _syncLocalAddOverrideChips();
    } catch (e) {
      if (gen != _formsPreviewGen) return;
      formsPreviewError.value = e.toString();
      _syncLocalAddOverrideChips();
    } finally {
      if (gen == _formsPreviewGen) formsPreviewLoading.value = false;
    }
  }

  Future<void> retryFormsPreview() =>
      _previewFormsAndMaybePersist(force: true);

  // ── Travel ───────────────────────────────────────────────────────────────

  ShiftTravelOut? _labourTravelClaim([List<ShiftTravelOut>? claims]) {
    for (final c in claims ?? travelClaims) {
      if (c.isLabour) return c;
    }
    return null;
  }

  void _seedTravelFromClaims(List<ShiftTravelOut> claims) {
    final labour = _labourTravelClaim(claims);
    if (labour == null) {
      travelLabourMinutes.value = '';
      travelMode.value = TravelApportionmentMode.equal;
      travelNominatedClientId.value = null;
      travelExplicitShares.clear();
      return;
    }
    travelLabourMinutes.value = labour.quantity.toString();
    travelMode.value = labour.apportionmentMode;
    if (labour.apportionmentMode == TravelApportionmentMode.nominated) {
      final nomineeSp = labour.nominatedParticipantId;
      String? clientId;
      for (final p in shiftParticipants) {
        if (p.id == nomineeSp) {
          clientId = p.participantId;
          break;
        }
      }
      travelNominatedClientId.value = clientId ?? nomineeSp;
    } else {
      travelNominatedClientId.value = null;
    }
    if (labour.apportionmentMode == TravelApportionmentMode.explicit) {
      final map = <String, String>{};
      for (final share in labour.shares) {
        String? clientId;
        for (final p in shiftParticipants) {
          if (p.id == share.shiftParticipantId) {
            clientId = p.participantId;
            break;
          }
        }
        map[clientId ?? share.shiftParticipantId] =
            share.quantityMinutes.toString();
      }
      travelExplicitShares.assignAll(map);
    } else {
      travelExplicitShares.clear();
    }
  }

  void setTravelLabourMinutes(String raw) {
    travelLabourMinutes.value = raw;
    travelError.value = null;
  }

  void setTravelMode(TravelApportionmentMode mode) {
    travelMode.value = mode;
    if (mode != TravelApportionmentMode.nominated) {
      travelNominatedClientId.value = null;
    }
    if (mode != TravelApportionmentMode.explicit) {
      travelExplicitShares.clear();
    }
    travelError.value = null;
  }

  void setTravelNominatedClientId(String? clientId) {
    travelNominatedClientId.value = clientId;
    travelError.value = null;
  }

  void setTravelExplicitShare(String clientId, String minutes) {
    final next = Map<String, String>.from(travelExplicitShares);
    if (minutes.trim().isEmpty) {
      next.remove(clientId);
    } else {
      next[clientId] = minutes.trim();
    }
    travelExplicitShares.assignAll(next);
    travelError.value = null;
  }

  String? validateTravelDraft() {
    return ComposerValidation.validateTravel(
      labourMinutes: travelLabourMinutes.value,
      mode: travelMode.value,
      nominatedClientId: travelNominatedClientId.value,
      explicitShares: Map<String, String>.from(travelExplicitShares),
    );
  }

  void beginOtherPlace() {
    if (draft.value.place is ShiftPlaceLabelled) return;
    otherAddressConfirmed.value = false;
    otherGeocodeFormatted.value = null;
    otherGeocodeError.value = null;
    otherLabelCtrl.clear();
    otherAddressLine1Ctrl.clear();
    otherCityCtrl.clear();
    otherStateCtrl.clear();
    otherPostalCtrl.clear();
    otherLatCtrl.clear();
    otherLngCtrl.clear();
    // Placeholder until lookup confirms — Next is blocked until coords exist.
    setPlace(
      const ShiftPlaceIn.labelled(
        label: '',
        latitude: 0,
        longitude: 0,
        postalCode: '',
      ),
    );
  }

  void invalidateOtherAddressConfirm() {
    if (!otherAddressConfirmed.value && otherGeocodeFormatted.value == null) {
      return;
    }
    otherAddressConfirmed.value = false;
    otherGeocodeFormatted.value = null;
    otherLatCtrl.clear();
    otherLngCtrl.clear();
  }

  Future<void> lookupOtherAddress() async {
    otherAddressConfirmed.value = false;
    final line1 = otherAddressLine1Ctrl.text.trim();
    final city = otherCityCtrl.text.trim();
    if (line1.isEmpty || city.isEmpty) {
      otherGeocodeError.value =
          'Enter address line 1 and suburb before looking up.';
      return;
    }
    otherIsGeocoding.value = true;
    otherGeocodeError.value = null;
    try {
      final result = await _clients.geocode(
        GeocodeRequest(
          addressLine1: line1,
          city: city,
          country:
              otherCountry.value.trim().isEmpty
                  ? 'AU'
                  : otherCountry.value.trim(),
          state:
              otherStateCtrl.text.trim().isEmpty
                  ? null
                  : otherStateCtrl.text.trim(),
        ),
      );
      final outcome = applyGeocodeResponse(
        result: result,
        latCtrl: otherLatCtrl,
        lngCtrl: otherLngCtrl,
        formattedAddress: otherGeocodeFormatted,
        addressConfirmed: otherAddressConfirmed,
        addressFallback: '$line1, $city',
      );
      if (!outcome.accepted) {
        otherGeocodeError.value = outcome.errorMessage;
        return;
      }
      commitOtherPlaceFromGeocode();
    } on AppFailure catch (e) {
      otherGeocodeError.value = e.message;
      otherGeocodeFormatted.value = null;
    } catch (e) {
      otherGeocodeError.value = e.toString();
      otherGeocodeFormatted.value = null;
    } finally {
      otherIsGeocoding.value = false;
    }
  }

  void confirmOtherAddress() {
    final lat = double.tryParse(otherLatCtrl.text.trim());
    final lng = double.tryParse(otherLngCtrl.text.trim());
    if (lat == null || lng == null) {
      otherGeocodeError.value = 'Look up an address before confirming.';
      return;
    }
    otherAddressConfirmed.value = true;
    otherGeocodeError.value = null;
    commitOtherPlaceFromGeocode();
  }

  void editOtherAddress() {
    otherAddressConfirmed.value = false;
    otherGeocodeFormatted.value = null;
    otherLatCtrl.clear();
    otherLngCtrl.clear();
    otherGeocodeError.value = null;
  }

  void commitOtherPlaceFromGeocode() {
    final lat = double.tryParse(otherLatCtrl.text.trim());
    final lng = double.tryParse(otherLngCtrl.text.trim());
    if (lat == null || lng == null) return;
    final label =
        otherLabelCtrl.text.trim().isNotEmpty
            ? otherLabelCtrl.text.trim()
            : (otherGeocodeFormatted.value ??
                otherAddressLine1Ctrl.text.trim());
    setPlace(
      ShiftPlaceIn.labelled(
        label: label,
        latitude: lat,
        longitude: lng,
        postalCode: otherPostalCtrl.text.trim(),
      ),
    );
  }

  /// Auto-lookup other address on Next when fields are filled but not confirmed.
  Future<bool> prepareOtherPlaceForAdvance() async {
    final place = draft.value.place;
    if (place is! ShiftPlaceLabelled) return true;
    if (otherAddressConfirmed.value &&
        otherLatCtrl.text.trim().isNotEmpty) {
      commitOtherPlaceFromGeocode();
      return true;
    }
    final line1 = otherAddressLine1Ctrl.text.trim();
    final city = otherCityCtrl.text.trim();
    if (line1.isEmpty || city.isEmpty) {
      stepError.value = ComposerValidation.otherAddressRequired;
      errorMessage.value = ComposerValidation.otherAddressRequired;
      otherGeocodeError.value = ComposerValidation.otherAddressRequired;
      return false;
    }
    await lookupOtherAddress();
    if (otherLatCtrl.text.trim().isEmpty) {
      stepError.value =
          otherGeocodeError.value ?? ComposerValidation.otherAddressRequired;
      errorMessage.value = stepError.value;
      return false;
    }
    // Wizard advance auto-confirms a successful non-low lookup.
    confirmOtherAddress();
    if (ComposerValidation.labelledPlacePostalMissing(draft.value.place)) {
      stepError.value = ComposerValidation.postalCodeRequired;
      errorMessage.value = ComposerValidation.postalCodeRequired;
      otherGeocodeError.value = ComposerValidation.postalCodeRequired;
      return false;
    }
    return otherAddressConfirmed.value;
  }

  Future<void> _persistTravelIfNeeded(String shiftId) async {
    final err = validateTravelDraft();
    if (err != null) {
      travelError.value = err;
      throw AppFailure(
        code: 'travel_invalid',
        message: err,
        presentation: AppFailurePresentation.inline,
      );
    }
    final minutes = travelLabourMinutes.value.trim();
    if (minutes.isEmpty) {
      // Empty OK — leave existing claims untouched (user can clear via UI later).
      return;
    }

    String? nominatedSpId;
    if (travelMode.value == TravelApportionmentMode.nominated) {
      nominatedSpId = _shiftParticipantIdForClient(
        travelNominatedClientId.value!,
      );
    }

    List<ShiftTravelShareIn>? shares;
    if (travelMode.value == TravelApportionmentMode.explicit) {
      shares = [
        for (final entry in travelExplicitShares.entries)
          ShiftTravelShareIn(
            shiftParticipantId: _shiftParticipantIdForClient(entry.key)!,
            quantityMinutes: entry.value,
          ),
      ];
    }

    final body = ShiftTravelWrite(
      claimKind: TravelClaimKind.labour,
      quantityMinutes: minutes,
      apportionmentMode: travelMode.value,
      nominatedParticipantId: nominatedSpId,
      shares: shares,
    );

    final existing = _labourTravelClaim();
    final saved =
        existing == null
            ? await _facade.createTravel(shiftId, body)
            : await _facade.updateTravel(shiftId, existing.id, body);
    travelClaims.assignAll([
      for (final c in travelClaims)
        if (!c.isLabour) c,
      saved,
    ]);
  }

  String? _shiftParticipantIdForClient(String clientId) {
    for (final p in shiftParticipants) {
      if (p.participantId == clientId && p.status == 'active') return p.id;
    }
    // Fallback: after create, ids may not be loaded yet — use client id only
    // when it already looks like a shift_participant row id.
    return clientId;
  }

  // ── Segments ─────────────────────────────────────────────────────────────

  /// shift_participant id → client participant id (active rows preferred).
  String? participantIdForShiftParticipant(String shiftParticipantId) {
    for (final p in shiftParticipants) {
      if (p.id == shiftParticipantId) return p.participantId;
    }
    return null;
  }

  /// client participant id → first active shift_participant id.
  Map<String, String> get participantIdToShiftParticipantId {
    final map = <String, String>{};
    for (final p in shiftParticipants) {
      if (p.status != 'active') continue;
      map.putIfAbsent(p.participantId, () => p.id);
    }
    return map;
  }

  /// After assign: reload live segments (BE expand / Mode A) into [segmentsByVisit].
  Future<void> refreshSegmentsAfterAssign(String shiftId) async {
    try {
      final composer = await _facade.getComposer(shiftId);
      final segments = <String, List<SupportSegmentOut>>{};
      for (final entry in composer.segmentsByVisit.entries) {
        segments[entry.key] = [
          for (final row in entry.value) SupportSegmentOut.fromJson(row),
        ];
      }
      segmentsByVisit.assignAll(segments);
      // Keep draft template in sync with server stamp when present.
      if (composer.shift.segmentTemplate.isNotEmpty) {
        setSegmentTemplate(composer.shift.segmentTemplate);
      }
    } catch (_) {
      // Best-effort: list per visit.
      final next = <String, List<SupportSegmentOut>>{};
      for (final visitId in visitIdsWithSegments) {
        try {
          next[visitId] = await _facade.listVisitSegments(shiftId, visitId);
        } catch (_) {}
      }
      if (next.isNotEmpty) segmentsByVisit.assignAll(next);
    }
  }

  /// Derive [OccurrenceDraft.segmentTemplate] from all live visit segments.
  /// Best-effort PATCH so Repeat/copy stay aligned without waiting for Save draft.
  Future<void> syncSegmentTemplateFromLiveSegments({
    bool patchRemote = true,
  }) async {
    final start = draft.value.scheduledStart;
    if (start == null) return;

    final windows = <LiveSegmentWindow>[
      for (final entry in segmentsByVisit.entries)
        for (final s in entry.value)
          LiveSegmentWindow(
            shiftParticipantId: s.shiftParticipantId,
            anchorSupportItemCode: s.anchorSupportItemCode,
            kind: s.kind,
            startAt: s.startAt.toLocal(),
            endAt: s.endAt.toLocal(),
            groupSize: s.groupSize,
            notes: s.notes,
          ),
    ];
    if (windows.isEmpty) return;

    final template = segmentTemplateFromLiveWindows(
      windowStart: start,
      segments: windows,
      participantIdForShiftParticipant: participantIdForShiftParticipant,
    );
    if (template.isEmpty) return;

    setSegmentTemplate(template);

    if (!patchRemote) return;
    final shiftId = draft.value.shiftId;
    if (shiftId == null || shiftId.isEmpty) return;
    try {
      await _facade.patchDraftShift(
        shiftId,
        ShiftPatchRequest(segmentTemplate: template),
      );
    } catch (_) {
      // Local draft updated; next Save draft persists.
    }
  }

  Future<void> saveVisitSegments(
    String visitId,
    List<SupportSegmentIn> segments,
  ) async {
    final shiftId = draft.value.shiftId;
    if (shiftId == null || shiftId.isEmpty) return;
    segmentsSaving.value = true;
    segmentsError.value = null;
    try {
      final saved = await _facade.putVisitSegments(shiftId, visitId, segments);
      final next = Map<String, List<SupportSegmentOut>>.from(segmentsByVisit);
      next[visitId] = saved;
      segmentsByVisit.assignAll(next);
      // Dual-write: live is source of truth; keep template for Repeat/copy.
      await syncSegmentTemplateFromLiveSegments();
    } on AppFailure catch (e) {
      segmentsError.value = e.message;
    } catch (e) {
      segmentsError.value = e.toString();
    } finally {
      segmentsSaving.value = false;
    }
  }

  // ── Workers / assign-context ─────────────────────────────────────────────

  /// Called when the Workers section mounts — never blocks Save draft.
  void onWorkersSectionOpened() {
    _workersSectionOpened = true;
    unawaited(_ensureEngagementsLoaded());
    scheduleAssignContextRefresh();
  }

  void scheduleAssignContextRefresh() {
    _assignDebounce?.cancel();
    _assignDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(loadAssignContext());
    });
  }

  Future<void> retryAssignContext() => loadAssignContext();

  Future<void> _ensureEngagementsLoaded() async {
    final repo = _engagements;
    if (repo == null) return;
    if (engagements.isNotEmpty) return;
    try {
      engagements.assignAll(await repo.listTenantEngagements());
    } catch (_) {
      // Non-blocking — picker may be empty without engagements.read.
    }
  }

  Future<void> loadAssignContext() async {
    final start = draft.value.scheduledStart;
    final end = draft.value.scheduledEnd;
    if (start == null || end == null) return;

    final gen = ++_assignContextGen;
    assignContextLoading.value = true;
    assignContextError.value = null;
    try {
      final tz = await _resolveTenantTimezone();
      final window = AssignScheduleWindow(
        dayCivil: DateTime(start.year, start.month, start.day),
        startCivil: start,
        endCivil: end,
      );
      final query = assignAvailabilityQueryWindow(
        window: window,
        tenantTimezone: tz,
      );
      final clientId =
          draft.value.clientId ??
          (draft.value.participantIds.isNotEmpty
              ? draft.value.participantIds.first
              : null);
      final result = await _facade.fetchAssignContext(
        from: query.from,
        to: query.to,
        clientId: clientId,
      );
      if (gen != _assignContextGen) return;
      assignContext.value = result;
    } on AppFailure catch (e) {
      if (gen != _assignContextGen) return;
      assignContextError.value = e.message;
      assignContext.value = null;
    } catch (e) {
      if (gen != _assignContextGen) return;
      assignContextError.value = e.toString();
      assignContext.value = null;
    } finally {
      if (gen == _assignContextGen) assignContextLoading.value = false;
    }
  }

  String availabilityLabelForContractor(String contractorId) {
    final ctx = assignContext.value;
    final start = draft.value.scheduledStart;
    final end = draft.value.scheduledEnd;
    if (ctx == null || start == null || end == null) return 'Unknown';
    final day = DateTime(start.year, start.month, start.day);
    return assignAvailabilityLabelFromContext(
      contractorId: contractorId,
      day: day,
      shiftStart: start,
      shiftEnd: end,
      context: ctx,
      windowStart: start,
      windowEnd: end,
      tenantTimezone: _session.tenantTimezone.value,
    );
  }

  /// Select/deselect a worker. Busy/Leave requires a non-empty override reason.
  Future<bool> selectContractor(
    String contractorId, {
    String? overrideReason,
  }) async {
    final selected = draft.value.contractorIds.contains(contractorId);
    if (selected) {
      final ids = [
        for (final id in draft.value.contractorIds)
          if (id != contractorId) id,
      ];
      draft.value = draft.value.copyWith(contractorIds: ids);
      assignOverrideReasons.remove(contractorId);
      return true;
    }

    final label = availabilityLabelForContractor(contractorId);
    if (assignLabelRequiresOverrideReason(label)) {
      var reason = overrideReason?.trim();
      if (reason == null || reason.isEmpty) {
        reason = (await _askAssignOverrideReason(label))?.trim();
      }
      if (reason == null || reason.isEmpty) {
        return false;
      }
      assignOverrideReasons[contractorId] = reason;
    }

    final ids = [...draft.value.contractorIds, contractorId];
    draft.value = draft.value.copyWith(contractorIds: ids);
    return true;
  }

  /// Slot-indexed assign for [WorkerSlotPicker]. Busy/Leave needs a reason.
  Future<bool> setContractorSlot(
    int index,
    String? contractorId, {
    String? overrideReason,
  }) async {
    final slotCount = workerSlotCount;
    final slots = List<String?>.generate(
      slotCount,
      (i) =>
          i < draft.value.contractorIds.length
              ? draft.value.contractorIds[i]
              : null,
    );
    while (slots.length < slotCount) {
      slots.add(null);
    }

    if (contractorId == null) {
      if (index < slots.length) {
        final removed = slots[index];
        slots[index] = null;
        if (removed != null) assignOverrideReasons.remove(removed);
      }
      draft.value = draft.value.copyWith(
        contractorIds: [
          for (final id in slots)
            if (id != null) id,
        ],
      );
      return true;
    }

    // Reject duplicate across slots.
    for (var i = 0; i < slots.length; i++) {
      if (i != index && slots[i] == contractorId) return false;
    }

    final label = availabilityLabelForContractor(contractorId);
    if (assignLabelRequiresOverrideReason(label)) {
      var reason = overrideReason?.trim();
      if (reason == null || reason.isEmpty) {
        reason = (await _askAssignOverrideReason(label))?.trim();
      }
      if (reason == null || reason.isEmpty) {
        return false;
      }
      assignOverrideReasons[contractorId] = reason;
    }

    if (index >= slots.length) {
      slots.add(contractorId);
    } else {
      final previous = slots[index];
      if (previous != null && previous != contractorId) {
        assignOverrideReasons.remove(previous);
      }
      slots[index] = contractorId;
    }
    draft.value = draft.value.copyWith(
      contractorIds: [
        for (final id in slots)
          if (id != null) id,
      ],
    );
    return true;
  }

  Future<String?> _askAssignOverrideReason(String label) async {
    if (_promptAssignOverrideReason != null) {
      return _promptAssignOverrideReason(label: label);
    }
    if (Get.testMode) return null;
    final ctrl = TextEditingController();
    try {
      final result = await Get.dialog<String>(
        AlertDialog(
          title: Text('Assign despite $label?'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: ctrl.text.trim()),
              child: const Text('Assign'),
            ),
          ],
        ),
      );
      if (result == null || result.isEmpty) return null;
      return result;
    } finally {
      ctrl.dispose();
    }
  }

  /// Keep one-session [clientId] and [participantIds] aligned before gates.
  void _syncParticipantsFromClientId() {
    if (draft.value.participantIds.isNotEmpty) return;
    final clientId = draft.value.clientId?.trim();
    if (clientId == null || clientId.isEmpty) return;
    draft.value = draft.value.copyWith(participantIds: [clientId]);
  }

  Future<bool> saveDraft() async {
    if (isSaving.value || !canManage) return false;
    errorMessage.value = null;
    saveErrorDetail.value = null;
    _retryHandler = null;
    _syncParticipantsFromClientId();

    final errors = ComposerValidation.validate(draft.value);
    if (errors.isNotEmpty) {
      errorMessage.value = errors.first;
      return false;
    }
    final allocErr = validateAllocationDraft();
    if (allocErr != null) {
      errorMessage.value = allocErr;
      return false;
    }

    final start = draft.value.scheduledStart;
    final end = draft.value.scheduledEnd;
    if (start == null || end == null) {
      errorMessage.value = 'Set start and end times';
      return false;
    }

    // Travel validation must not block Save when empty; only when partial/invalid.
    final travelErr = validateTravelDraft();
    if (travelErr != null) {
      travelError.value = travelErr;
      errorMessage.value = travelErr;
      return false;
    }

    isSaving.value = true;
    try {
      final tz = await _resolveTenantTimezone();
      final startUtc = tenantCivilInstantUtc(start, tz);
      final endUtc = tenantCivilInstantUtc(end, tz);

      ShiftOut? persisted;
      if (!hasPersistedShift) {
        final jobId = await _resolveJobIdForCreate();
        // Create without contractors when per-worker override reasons exist;
        // otherwise materialize can draft-assign in one shot.
        final reasons = _assignReasonsForSelected();
        persisted = await _facade.createShift(
          ShiftCreateRequest(
            jobId: jobId,
            scheduledStart: startUtc,
            scheduledEnd: endUtc,
            place: draft.value.place,
            requiredSlots: draft.value.requiredSlots,
            workerCount: draft.value.workerCount,
            status: 'draft',
            contractorIds:
                reasons.isEmpty ? draft.value.contractorIds : const [],
            taskTemplate: draft.value.taskTemplate,
            segmentTemplate: draft.value.segmentTemplate,
            supportItemCode: draft.value.supportItemCode,
            equalSplit: _useEqualSplitOnSave,
            participants: _participantCreateItems(),
          ),
        );
        draft.value = draft.value.copyWith(
          shiftId: persisted.id,
          jobId: persisted.jobId,
          status: persisted.status,
        );
      } else {
        final shiftId = draft.value.shiftId!;
        persisted = await _facade.patchDraftShift(
          shiftId,
          ShiftPatchRequest(
            place: draft.value.place,
            scheduledStart: startUtc,
            scheduledEnd: endUtc,
            requiredSlots: draft.value.requiredSlots,
            workerCount: draft.value.workerCount,
            taskTemplate: draft.value.taskTemplate,
            segmentTemplate: draft.value.segmentTemplate,
          ),
        );
        persisted = await _facade.putParticipants(
          shiftId,
          ShiftParticipantsReplaceRequest(
            allocationStrategy: 'percentage',
            equalSplit: _useEqualSplitOnSave,
            participants: _participantReplaceItems(),
          ),
        );
      }

      final shiftId = draft.value.shiftId!;
      persisted = await _syncDraftAssignments(shiftId, persisted);

      shiftParticipants.assignAll(persisted.participants);
      assignments.assignAll(persisted.assignments);

      // After assign, BE expands segment_template (or Mode A) — refresh live rows.
      if (visitIdsWithSegments.isNotEmpty) {
        await refreshSegmentsAfterAssign(shiftId);
      }

      if (formOverrides.isNotEmpty || _formsEdited) {
        await _facade.putFormOverrides(
          shiftId,
          formOverrides.toList(growable: false),
        );
      }
      await _persistTravelIfNeeded(shiftId);

      if (draft.value.repeatEnabled) {
        final repeatOk = await saveRepeatRule();
        if (!repeatOk) return false;
      }

      if (!Get.testMode) {
        AppToast.success('Draft saved', 'You can keep editing or publish.');
      }
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      saveErrorDetail.value = e.message;
      _retryHandler = () async {
        await saveDraft();
      };
      if (!Get.testMode) AppToast.error('Could not save', e.message);
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      saveErrorDetail.value = e.toString();
      _retryHandler = () async {
        await saveDraft();
      };
      if (!Get.testMode) AppToast.error('Could not save', e.toString());
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Map<String, String> _assignReasonsForSelected() => {
    for (final id in draft.value.contractorIds)
      if (assignOverrideReasons[id] != null &&
          assignOverrideReasons[id]!.trim().isNotEmpty)
        id: assignOverrideReasons[id]!.trim(),
  };

  /// Align server assignments with [OccurrenceDraft.contractorIds] on draft save.
  Future<ShiftOut> _syncDraftAssignments(
    String shiftId,
    ShiftOut current,
  ) async {
    final desired = draft.value.contractorIds.toSet();
    final existing = {
      for (final a in current.assignments)
        if (a.status == 'active') a.contractorId,
    };

    var latest = current;
    for (final id in existing.difference(desired)) {
      latest = await _facade.unassignShift(shiftId, id);
    }

    final toAdd = desired.difference({
      for (final a in latest.assignments)
        if (a.status == 'active') a.contractorId,
    });
    if (toAdd.isEmpty) return latest;

    final reasons = {
      for (final id in toAdd)
        if (assignOverrideReasons[id] != null &&
            assignOverrideReasons[id]!.trim().isNotEmpty)
          id: assignOverrideReasons[id]!.trim(),
    };
    final taskTemplate =
        draft.value.taskTemplate.isEmpty ? null : draft.value.taskTemplate;

    // Prefer batch when no override reasons; fall back to one-by-one on gate.
    if (reasons.isEmpty) {
      try {
        return await _facade.assignShiftBatch(
          shiftId: shiftId,
          contractorIds: toAdd.toList(growable: false),
          taskTemplate: taskTemplate,
        );
      } on AppFailure catch (e) {
        if (!_isAssignOrCredentialGate(e)) rethrow;
        credentialGateReasons.assignAll(e.eligibilityReasons);
        // Continue one-by-one so each worker can get an audited override.
      }
    }

    for (final id in toAdd) {
      latest = await _assignWithCredentialGate(
        shiftId: shiftId,
        contractorId: id,
        taskTemplate: taskTemplate,
        overrideReason: reasons[id],
      );
    }
    return latest;
  }

  Future<ShiftOut> _assignWithCredentialGate({
    required String shiftId,
    required String contractorId,
    List<TaskTemplateItem>? taskTemplate,
    String? overrideReason,
  }) async {
    try {
      return await _facade.assignShift(
        shiftId: shiftId,
        contractorId: contractorId,
        taskTemplate: taskTemplate,
        reason: overrideReason,
      );
    } on AppFailure catch (e) {
      if (!_isAssignOrCredentialGate(e)) rethrow;
      credentialGateReasons.assignAll(e.eligibilityReasons);
      if (overrideReason != null && overrideReason.trim().isNotEmpty) {
        rethrow;
      }
      final reason = await promptCredentialGateOverride(
        reasons: e.eligibilityReasons,
        title:
            e.isAssignGateBlocked
                ? 'Care / compatibility block'
                : 'Credentials block assign',
      );
      if (reason == null || reason.trim().isEmpty) rethrow;
      assignOverrideReasons[contractorId] = reason.trim();
      return _facade.assignShift(
        shiftId: shiftId,
        contractorId: contractorId,
        taskTemplate: taskTemplate,
        reason: reason.trim(),
      );
    }
  }

  bool _isAssignOrCredentialGate(AppFailure e) =>
      e.isCredentialGateBlocked ||
      e.isAssignGateBlocked ||
      e.isEligibilityIncomplete;

  /// Group: program job + shift place. One-session: standing job for client.
  /// Never [JobsRepository.ensureOngoingSupport] with a group "host".
  Future<String> _resolveJobIdForCreate() async {
    final existing = draft.value.jobId;
    if (existing != null && existing.isNotEmpty) {
      try {
        final job = await _facade.jobs.getJob(existing);
        final wantProgram = draft.value.preset == ComposerPreset.group;
        final kindOk = wantProgram ? job.isProgram : job.isStanding;
        if (kindOk) return existing;
        // Kind mismatch (e.g. preset switch left a stale id) — recreate below.
      } catch (_) {
        // Stale/missing job — recreate below.
      }
      draft.value = draft.value.copyWith(clearJobId: true);
    }

    if (draft.value.preset == ComposerPreset.oneSession) {
      final clientId =
          draft.value.clientId ??
          (draft.value.participantIds.isNotEmpty
              ? draft.value.participantIds.first
              : null);
      if (clientId == null) {
        throw const AppFailure(
          code: 'client_required',
          message: 'Add a client before saving',
          presentation: AppFailurePresentation.inline,
        );
      }
      final job = await _facade.jobs.ensureOngoingSupport(clientId);
      draft.value = draft.value.copyWith(jobId: job.id);
      return job.id;
    }

    // Group → kind=program (P0-7). Prefer branch from place; else first option.
    final branchId = _branchIdForProgramJob();
    if (branchId == null || branchId.isEmpty) {
      throw const AppFailure(
        code: 'place_required',
        message: 'Add a place before saving a group session',
        presentation: AppFailurePresentation.inline,
      );
    }
    final created = await _facade.jobs.createJob(
      JobCreateRequest(
        kind: 'program',
        title: 'Group session',
        branchId: branchId,
        supportItemCode: draft.value.supportItemCode,
        supportItemName:
            supportItemName.value.trim().isEmpty
                ? null
                : supportItemName.value.trim(),
      ),
    );
    draft.value = draft.value.copyWith(jobId: created.id);
    return created.id;
  }

  String? _branchIdForProgramJob() {
    final place = draft.value.place;
    if (place is ShiftPlaceBranch) return place.branchId;
    final branches = placeOptions.value.branches;
    if (branches.isNotEmpty) return branches.first.id;
    return null;
  }

  Future<bool> _confirmOpenSlotsPublish(int unassigned) async {
    if (_confirmPublishOpenSlots != null) {
      return _confirmPublishOpenSlots(unassigned);
    }
    if (Get.testMode) return true;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Publish with open slots?'),
        content: Text(
          unassigned == 1
              ? '1 worker slot is unassigned. Once published, contractors can claim it.'
              : '$unassigned worker slots are unassigned. Once published, contractors can claim them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Publish: assign chosen contractors; any empty slots stay claimable.
  ///
  /// On credential / budget hard-block, prompts for an audited override and
  /// retries (same contract as board [StaffVisitsController.publishSelectedShift]).
  Future<bool> publish({
    String? overrideReason,
    String? budgetOverrideReason,
    bool skipOpenSlotsConfirm = false,
    bool skipSaveDraft = false,
  }) async {
    if (isPublishing.value || !canManage) return false;
    _retryHandler = null;
    _syncParticipantsFromClientId();

    if (!skipSaveDraft) {
      final errors = ComposerValidation.validate(
        draft.value,
        forPublish: true,
      );
      if (errors.isNotEmpty) {
        errorMessage.value = errors.first;
        return false;
      }

      final open = unassignedSlotCount;
      if (open > 0 && !skipOpenSlotsConfirm) {
        final ok = await _confirmOpenSlotsPublish(open);
        if (!ok) return false;
      }

      final saved = await saveDraft();
      if (!saved || draft.value.shiftId == null) return false;
    } else if (draft.value.shiftId == null) {
      return false;
    }

    final open = unassignedSlotCount;
    isPublishing.value = true;
    errorMessage.value = null;
    credentialGateReasons.clear();
    try {
      final shiftId = draft.value.shiftId!;
      // Assignments are already synced in saveDraft — do not assign again
      // (that surfaces contractor_already_assigned).

      final published = await _facade.publishShift(
        shiftId,
        body: ShiftPublishRequest(
          supportItemCode: draft.value.supportItemCode,
          overrideReason: overrideReason,
          budgetOverrideReason: budgetOverrideReason,
        ),
      );
      draft.value = draft.value.copyWith(status: published.status);
      if (!Get.testMode) {
        AppToast.success(
          open > 0 ? 'Published — open slots claimable' : 'Published',
          published.jobTitle,
        );
      }
      // Do not auto-navigate to travel (soft cutover L3/travel rule).
      _navigate(AppRoutes.staffShiftDetail, published);
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = _mapPublishError(e);
      if (_isAssignOrCredentialGate(e)) {
        credentialGateReasons.assignAll(e.eligibilityReasons);
        if (overrideReason == null || overrideReason.trim().isEmpty) {
          final reason = await promptCredentialGateOverride(
            reasons: e.eligibilityReasons,
            title:
                e.isAssignGateBlocked
                    ? 'Care / compatibility block'
                    : 'Credentials block assign',
          );
          if (reason != null && reason.trim().isNotEmpty) {
            isPublishing.value = false;
            return publish(
              overrideReason: reason.trim(),
              budgetOverrideReason: budgetOverrideReason,
              skipOpenSlotsConfirm: true,
              skipSaveDraft: true,
            );
          }
        }
      } else if (e.isBudgetBurnBlocked) {
        if (budgetOverrideReason == null ||
            budgetOverrideReason.trim().isEmpty) {
          if (!_session.hasPermission(AppPermissions.billingManage)) {
            if (!Get.testMode) {
              AppToast.error(
                'Could not publish',
                'Plan budget override requires billing.manage.',
              );
            }
          } else {
            final reason = await promptBudgetBurnOverride(
              reasons:
                  e.eligibilityReasons.isEmpty
                      ? const ['Plan budget hard block']
                      : e.eligibilityReasons,
            );
            if (reason != null && reason.trim().isNotEmpty) {
              isPublishing.value = false;
              return publish(
                overrideReason: overrideReason,
                budgetOverrideReason: reason.trim(),
                skipOpenSlotsConfirm: true,
                skipSaveDraft: true,
              );
            }
          }
        }
      } else if (!e.isBudgetOverrideForbidden) {
        _retryHandler = () async {
          await publish(
            overrideReason: overrideReason,
            budgetOverrideReason: budgetOverrideReason,
            skipOpenSlotsConfirm: true,
            skipSaveDraft: true,
          );
        };
      }
      if (!Get.testMode &&
          !_isAssignOrCredentialGate(e) &&
          !e.isBudgetBurnBlocked) {
        AppToast.error('Could not publish', errorMessage.value!);
      } else if (!Get.testMode && e.isBudgetOverrideForbidden) {
        AppToast.error('Could not publish', e.message);
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      _retryHandler = () async {
        await publish(
          overrideReason: overrideReason,
          budgetOverrideReason: budgetOverrideReason,
          skipOpenSlotsConfirm: true,
          skipSaveDraft: true,
        );
      };
      if (!Get.testMode) AppToast.error('Could not publish', e.toString());
      return false;
    } finally {
      isPublishing.value = false;
    }
  }

  /// Budget hard-block override (C6) — distinct copy from credential gate.
  @visibleForTesting
  Future<String?> promptBudgetBurnOverride({
    required List<String> reasons,
  }) async {
    final custom = _promptBurnOverride;
    if (custom != null) return custom(reasons: reasons);
    if (Get.testMode) return null;
    final controller = TextEditingController();
    final result = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Plan budget hard block'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Publishing would exceed declared plan envelopes '
                '(ledger vs declared — not a live NDIA balance).',
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final r in reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $r', style: const TextStyle(fontSize: 13)),
                  ),
              ],
              const SizedBox(height: 12),
              const Text(
                'To continue, enter an audited override reason '
                '(no silent bypass).',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Override reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Get.back(result: text);
            },
            child: const Text('Override & publish'),
          ),
        ],
      ),
    );
    return result;
  }

  @visibleForTesting
  Future<String?> promptCredentialGateOverride({
    required List<String> reasons,
    String title = 'Credentials block assign',
  }) async {
    final custom = _promptCredentialGateOverride;
    if (custom != null) {
      return custom(reasons: reasons, title: title);
    }
    if (Get.testMode) return null;
    final controller = TextEditingController();
    final result = await Get.dialog<String>(
      AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EligibilityIncompletePanel(title: title, reasons: reasons),
              const SizedBox(height: 12),
              const Text(
                'To continue, enter an audited override reason '
                '(no silent bypass).',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Override reason',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Get.back(result: text);
            },
            child: const Text('Assign with override'),
          ),
        ],
      ),
    );
    return result;
  }

  String _mapPublishError(AppFailure e) {
    switch (e.code) {
      case 'support_item_required':
        return ComposerValidation.supportAnchorRequired;
      case 'participants_required':
        return 'Add participants before publishing';
      case 'contractor_already_assigned':
        // Should be rare after saveDraft sync; treat as non-fatal race.
        return 'A selected worker is already assigned to this shift.';
      case 'budget_burn_blocked':
        return e.message;
      case 'budget_override_forbidden':
        return e.message;
      default:
        return e.message;
    }
  }

  void _navigate(String route, dynamic arguments) {
    if (_onNavigate != null) {
      _onNavigate(route, arguments);
      return;
    }
    if (Get.testMode) return;
    // Prefer AppNavigator so web GoRouter gets query/extra (not Get.offNamed).
    if (arguments is ShiftOut) {
      AppNavigator.go(
        AppNavigator.location(route, query: {'id': arguments.id}),
        extra: arguments,
      );
      return;
    }
    AppNavigator.go(route, extra: arguments);
  }

  Future<String?> _resolveTenantTimezone() async {
    final sessionTz = _session.tenantTimezone.value?.trim();
    if (sessionTz != null && sessionTz.isNotEmpty) return sessionTz;
    if (Get.isRegistered<StaffTenantSettingsController>()) {
      final tz =
          Get.find<StaffTenantSettingsController>().tenant.value?.timezone;
      if (tz != null && tz.trim().isNotEmpty) return tz.trim();
    }
    return null;
  }
}

class _PublishedBounce implements Exception {}
