import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/constants/app_permissions.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/session_service.dart';
import '../../../../core/time/tenant_civil_time.dart';
import '../../../../shared/utils/name_sort.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../clients/data/models/client_models.dart';
import '../../../clients/data/repositories/clients_repository.dart';
import '../../../engagements/data/models/engagement_models.dart';
import '../../../engagements/data/repositories/engagements_repository.dart';
import '../../../jobs/data/models/job_models.dart';
import '../../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../../shifts/data/models/shift_models.dart';
import '../../../shifts/data/models/shift_travel_models.dart';
import '../../../shifts/utils/allocation_math.dart';
import '../../../visits/utils/assign_schedule_window.dart';
import '../../data/composer_facade.dart';
import '../../data/composer_models.dart';
import '../../domain/composer_validation.dart';
import '../../domain/occurrence_draft.dart';
import '../../domain/roster_composer_args.dart';
import '../../domain/travel_shares_validation.dart';
import '../shared/assign_context_labels.dart';

/// Publish menu choice (Assign & publish vs Open for claim).
enum ComposerPublishMode { assignAndPublish, openForClaim }

/// Unified rostering occurrence composer (Stage A shell).
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
  }) : _facade = facade,
       _clients = clientsRepository,
       _session = session,
       _engagements = engagementsRepository,
       _args = args ?? const RosterComposerArgs(),
       _onNavigate = onNavigate,
       _confirmLargeGroup = confirmLargeGroup,
       _promptAssignOverrideReason = promptAssignOverrideReason;

  final ComposerFacade _facade;
  final ClientsRepository _clients;
  final SessionService _session;
  final EngagementsRepository? _engagements;
  final RosterComposerArgs _args;
  final void Function(String route, dynamic arguments)? _onNavigate;
  final Future<bool> Function(int nextN)? _confirmLargeGroup;
  final Future<String?> Function({required String label})?
  _promptAssignOverrideReason;

  final draft = OccurrenceDraft.oneSession().obs;
  final focusSection = ComposerFocusSection.plan.obs;

  final clients = <ClientOut>[].obs;
  final clientSearch = ''.obs;
  final placeOptions = const PlaceOptionsOut().obs;
  final placeOptionsLoading = false.obs;
  final placeOptionsError = RxnString();

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
  bool _workersSectionOpened = false;

  final isHydrating = true.obs;
  final isSaving = false.obs;
  final isPublishing = false.obs;
  final errorMessage = RxnString();
  final saveErrorDetail = RxnString();

  final showPublishMenu = false.obs;

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
    // Skeleton first paint < 300ms — do not block onInit on network.
    isHydrating.value = true;
    unawaited(_bootstrap());
  }

  @override
  void onClose() {
    _placeDebounce?.cancel();
    _formsDebounce?.cancel();
    _assignDebounce?.cancel();
    _placeFetchGen++;
    _formsPreviewGen++;
    _assignContextGen++;
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
    try {
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
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isHydrating.value = false;
    }
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
    _applyComposerSeed(composer, repeatEnabled: _args.repeatEnabled);
    unawaited(() async {
      try {
        clients.assignAll(await _clients.listClients());
      } catch (_) {}
    }());
    unawaited(_loadFormTemplates());
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
    return null;
  }

  void _bounceToDetail(ShiftOut shift) {
    _navigate(AppRoutes.staffShiftDetail, shift);
  }

  void setPreset(ComposerPreset preset) {
    if (draft.value.preset == preset) return;
    final current = draft.value;
    if (preset == ComposerPreset.oneSession) {
      final clientId =
          current.clientId ??
          (current.participantIds.isNotEmpty
              ? current.participantIds.first
              : null);
      draft.value = current.copyWith(
        preset: preset,
        clientId: clientId,
        participantIds: clientId != null ? [clientId] : const [],
        workerCount: 1,
        requiredSlots: 1,
        equalSplit: true,
      );
    } else {
      draft.value = current.copyWith(preset: preset);
    }
    schedulePlaceOptionsRefresh();
  }

  void setRepeatEnabled(bool enabled) {
    draft.value = draft.value.copyWith(repeatEnabled: enabled);
  }

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
  }

  void setSupportItemCode(String? code) {
    draft.value =
        (code == null || code.isEmpty)
            ? draft.value.copyWith(clearSupportItemCode: true)
            : draft.value.copyWith(supportItemCode: code);
  }

  void setWorkerCount(int n) {
    draft.value = draft.value.copyWith(workerCount: n < 1 ? 1 : n);
  }

  void setRequiredSlots(int n) {
    draft.value = draft.value.copyWith(requiredSlots: n < 1 ? 1 : n);
  }

  void setEqualSplit(bool equal) {
    draft.value = draft.value.copyWith(equalSplit: equal);
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
    if (!clients.any((c) => c.id == client.id)) clients.add(client);
    schedulePlaceOptionsRefresh();
    return true;
  }

  void removeParticipant(String participantId) {
    final ids = [
      for (final id in draft.value.participantIds)
        if (id != participantId) id,
    ];
    draft.value = draft.value.copyWith(participantIds: ids);
    schedulePlaceOptionsRefresh();
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
    _onFormsEdited();
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

  Future<void> _previewFormsAndMaybePersist() async {
    final jobId = draft.value.jobId;
    if (jobId == null || jobId.isEmpty) return;
    if (!_formsEdited) return;

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

      if (hasPersistedShift) {
        await _facade.putFormOverrides(
          draft.value.shiftId!,
          formOverrides.toList(growable: false),
        );
      }
    } on AppFailure catch (e) {
      if (gen != _formsPreviewGen) return;
      formsPreviewError.value = e.message;
    } catch (e) {
      if (gen != _formsPreviewGen) return;
      formsPreviewError.value = e.toString();
    } finally {
      if (gen == _formsPreviewGen) formsPreviewLoading.value = false;
    }
  }

  Future<void> retryFormsPreview() => _previewFormsAndMaybePersist();

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
    final minutes = travelLabourMinutes.value.trim();
    if (minutes.isEmpty) return null; // empty OK
    if (travelMode.value == TravelApportionmentMode.nominated &&
        (travelNominatedClientId.value == null ||
            travelNominatedClientId.value!.isEmpty)) {
      return 'Choose a nominated participant';
    }
    if (travelMode.value == TravelApportionmentMode.explicit) {
      return TravelSharesValidation.explicitSumMismatch(
        journeyMinutes: minutes,
        shareMinutesByParticipant: Map<String, String>.from(
          travelExplicitShares,
        ),
      );
    }
    final parsed = double.tryParse(minutes);
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return 'Travel minutes must be greater than 0';
    }
    return null;
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
    final slotCount =
        draft.value.showsWorkerCount ? draft.value.workerCount : 1;
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

  Future<bool> saveDraft() async {
    if (isSaving.value || !canManage) return false;
    errorMessage.value = null;
    saveErrorDetail.value = null;

    final errors = ComposerValidation.validate(draft.value);
    if (errors.isNotEmpty) {
      errorMessage.value = errors.first;
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
        persisted = await _facade.createShift(
          ShiftCreateRequest(
            jobId: jobId,
            scheduledStart: startUtc,
            scheduledEnd: endUtc,
            place: draft.value.place,
            requiredSlots: draft.value.requiredSlots,
            workerCount: draft.value.workerCount,
            status: 'draft',
            contractorIds: const [],
            taskTemplate: draft.value.taskTemplate,
            segmentTemplate: draft.value.segmentTemplate,
            supportItemCode: draft.value.supportItemCode,
            equalSplit: draft.value.equalSplit,
            participants: [
              for (final id in draft.value.participantIds)
                ShiftParticipantCreateItem(
                  participantId: id,
                  allocationStrategy: 'percentage',
                  reason: 'roster_composer',
                  allocationValue: draft.value.equalSplit ? null : null,
                ),
            ],
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
            segmentTemplate:
                draft.value.segmentTemplate.isEmpty
                    ? null
                    : draft.value.segmentTemplate,
          ),
        );
        persisted = await _facade.putParticipants(
          shiftId,
          ShiftParticipantsReplaceRequest(
            allocationStrategy: 'percentage',
            equalSplit: draft.value.equalSplit,
            participants: [
              for (final id in draft.value.participantIds)
                ShiftParticipantReplaceItem(participantId: id),
            ],
          ),
        );
      }

      shiftParticipants.assignAll(persisted.participants);
      assignments.assignAll(persisted.assignments);

      final shiftId = draft.value.shiftId!;
      if (formOverrides.isNotEmpty || _formsEdited) {
        await _facade.putFormOverrides(
          shiftId,
          formOverrides.toList(growable: false),
        );
      }
      await _persistTravelIfNeeded(shiftId);

      if (!Get.testMode) {
        AppToast.success('Draft saved', 'You can keep editing or publish.');
      }
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      saveErrorDetail.value = e.message;
      if (!Get.testMode) AppToast.error('Could not save', e.message);
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      saveErrorDetail.value = e.toString();
      if (!Get.testMode) AppToast.error('Could not save', e.toString());
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Group: program job + shift place. One-session: standing job for client.
  /// Never [JobsRepository.ensureOngoingSupport] with a group "host".
  Future<String> _resolveJobIdForCreate() async {
    final existing = draft.value.jobId;
    if (existing != null && existing.isNotEmpty) return existing;

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

  void openPublishMenu() => showPublishMenu.value = true;
  void closePublishMenu() => showPublishMenu.value = false;

  Future<bool> publish(ComposerPublishMode mode) async {
    if (isPublishing.value || !canManage) return false;
    closePublishMenu();

    final errors = ComposerValidation.validate(
      draft.value,
      forPublish: true,
    );
    if (errors.isNotEmpty) {
      errorMessage.value = errors.first;
      return false;
    }

    final saved = await saveDraft();
    if (!saved || draft.value.shiftId == null) return false;

    isPublishing.value = true;
    errorMessage.value = null;
    try {
      final shiftId = draft.value.shiftId!;

      if (mode == ComposerPublishMode.assignAndPublish &&
          draft.value.contractorIds.isNotEmpty) {
        // Assign one-by-one when override reasons differ; batch when none.
        final reasons = {
          for (final id in draft.value.contractorIds)
            if (assignOverrideReasons[id] != null) id: assignOverrideReasons[id]!,
        };
        if (reasons.isEmpty) {
          await _facade.assignShiftBatch(
            shiftId: shiftId,
            contractorIds: draft.value.contractorIds,
            taskTemplate:
                draft.value.taskTemplate.isEmpty
                    ? null
                    : draft.value.taskTemplate,
          );
        } else {
          for (final id in draft.value.contractorIds) {
            await _facade.assignShift(
              shiftId: shiftId,
              contractorId: id,
              taskTemplate:
                  draft.value.taskTemplate.isEmpty
                      ? null
                      : draft.value.taskTemplate,
              reason: reasons[id],
            );
          }
        }
      }

      final published = await _facade.publishShift(
        shiftId,
        body: ShiftPublishRequest(
          supportItemCode: draft.value.supportItemCode,
        ),
      );
      draft.value = draft.value.copyWith(status: published.status);
      if (!Get.testMode) {
        AppToast.success(
          mode == ComposerPublishMode.openForClaim
              ? 'Open for claim'
              : 'Published',
          published.jobTitle,
        );
      }
      // Do not auto-navigate to travel (soft cutover L3/travel rule).
      _navigate(AppRoutes.staffShiftDetail, published);
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = _mapPublishError(e);
      if (!Get.testMode) {
        AppToast.error('Could not publish', errorMessage.value!);
      }
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      if (!Get.testMode) AppToast.error('Could not publish', e.toString());
      return false;
    } finally {
      isPublishing.value = false;
    }
  }

  String _mapPublishError(AppFailure e) {
    switch (e.code) {
      case 'support_item_required':
        return ComposerValidation.supportAnchorRequired;
      case 'participants_required':
        return 'Add participants before publishing';
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
    Get.offNamed(route, arguments: arguments);
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
