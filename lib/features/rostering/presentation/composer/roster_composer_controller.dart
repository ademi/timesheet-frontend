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
import '../../../jobs/data/models/job_models.dart';
import '../../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../../shifts/data/models/shift_models.dart';
import '../../../shifts/utils/allocation_math.dart';
import '../../data/composer_facade.dart';
import '../../data/composer_models.dart';
import '../../domain/composer_validation.dart';
import '../../domain/occurrence_draft.dart';
import '../../domain/roster_composer_args.dart';

/// Publish menu choice (Assign & publish vs Open for claim).
enum ComposerPublishMode { assignAndPublish, openForClaim }

/// Unified rostering occurrence composer (Stage A shell).
class RosterComposerController extends GetxController {
  RosterComposerController({
    required ComposerFacade facade,
    required ClientsRepository clientsRepository,
    required SessionService session,
    RosterComposerArgs? args,
    void Function(String route, dynamic arguments)? onNavigate,
    Future<bool> Function(int nextN)? confirmLargeGroup,
  }) : _facade = facade,
       _clients = clientsRepository,
       _session = session,
       _args = args ?? const RosterComposerArgs(),
       _onNavigate = onNavigate,
       _confirmLargeGroup = confirmLargeGroup;

  final ComposerFacade _facade;
  final ClientsRepository _clients;
  final SessionService _session;
  final RosterComposerArgs _args;
  final void Function(String route, dynamic arguments)? _onNavigate;
  final Future<bool> Function(int nextN)? _confirmLargeGroup;

  final draft = OccurrenceDraft.oneSession().obs;
  final focusSection = ComposerFocusSection.plan.obs;

  final clients = <ClientOut>[].obs;
  final clientSearch = ''.obs;
  final placeOptions = const PlaceOptionsOut().obs;
  final placeOptionsLoading = false.obs;
  final placeOptionsError = RxnString();

  final isHydrating = true.obs;
  final isSaving = false.obs;
  final isPublishing = false.obs;
  final errorMessage = RxnString();
  final saveErrorDetail = RxnString();

  final showPublishMenu = false.obs;

  Timer? _placeDebounce;
  int _placeFetchGen = 0;

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
    _placeFetchGen++;
    super.onClose();
  }

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
    draft.value = _draftFromShift(
      composer.shift,
      preset: _inferPreset(composer.shift),
      repeatEnabled: _args.repeatEnabled,
    );
    unawaited(() async {
      try {
        clients.assignAll(await _clients.listClients());
      } catch (_) {}
    }());
    schedulePlaceOptionsRefresh();
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

    isSaving.value = true;
    try {
      final tz = await _resolveTenantTimezone();
      final startUtc = tenantCivilInstantUtc(start, tz);
      final endUtc = tenantCivilInstantUtc(end, tz);

      if (!hasPersistedShift) {
        final jobId = await _resolveJobIdForCreate();
        final created = await _facade.createShift(
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
          shiftId: created.id,
          jobId: created.jobId,
          status: created.status,
        );
      } else {
        final shiftId = draft.value.shiftId!;
        await _facade.patchDraftShift(
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
        await _facade.putParticipants(
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
        await _facade.assignShiftBatch(
          shiftId: shiftId,
          contractorIds: draft.value.contractorIds,
          taskTemplate:
              draft.value.taskTemplate.isEmpty
                  ? null
                  : draft.value.taskTemplate,
        );
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
