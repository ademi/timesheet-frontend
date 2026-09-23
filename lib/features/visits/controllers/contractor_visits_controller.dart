import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';
import '../services/visit_location_service.dart';
import '../sync/outbox_models.dart';
import '../sync/outbox_store.dart';
import '../sync/sync_error_classifier.dart';
import '../sync/sync_worker.dart';
import '../../documents/sync/media_blob_store.dart';
import '../../documents/sync/media_outbox_models.dart';
import '../../documents/sync/media_outbox_store.dart';
import '../../documents/sync/media_sync_worker.dart';

enum VisitClockSyncUi { none, pending, failed }

/// Maps outbox rows for a visit to chip state.
/// Retryable [ClockOutboxItem.lastError] stays Pending; only [isConflict]
/// (terminal) maps to SyncFailed.
VisitClockSyncUi clockSyncUiFor(Iterable<ClockOutboxItem> items) {
  final list = items.toList(growable: false);
  if (list.isEmpty) return VisitClockSyncUi.none;
  if (list.any((e) => e.isConflict)) return VisitClockSyncUi.failed;
  return VisitClockSyncUi.pending;
}

class ContractorVisitsController extends GetxController {
  ContractorVisitsController({
    required VisitsRepository repository,
    required ShiftsRepository shiftsRepository,
    required SessionService session,
    VisitLocationService location = const VisitLocationService(),
    OutboxStore? outbox,
    SyncWorker? syncWorker,
    MediaOutboxStore? mediaOutbox,
    MediaSyncWorker? mediaSyncWorker,
    MediaBlobStore? mediaBlobs,
    Future<bool> Function()? isDeviceOffline,
    String Function()? newEventId,
    Future<String?> Function()? promptLateReason,
  }) : _repository = repository,
       _shiftsRepository = shiftsRepository,
       _session = session,
       _location = location,
       _outboxOverride = outbox,
       _syncWorkerOverride = syncWorker,
       _mediaOutboxOverride = mediaOutbox,
       _mediaSyncWorkerOverride = mediaSyncWorker,
       _mediaBlobsOverride = mediaBlobs,
       _isDeviceOffline = isDeviceOffline,
       _newEventId = newEventId ?? const Uuid().v4,
       _promptLateReason = promptLateReason;

  final VisitsRepository _repository;
  final ShiftsRepository _shiftsRepository;
  final SessionService _session;
  final VisitLocationService _location;
  final OutboxStore? _outboxOverride;
  final SyncWorker? _syncWorkerOverride;
  final MediaOutboxStore? _mediaOutboxOverride;
  final MediaSyncWorker? _mediaSyncWorkerOverride;
  final MediaBlobStore? _mediaBlobsOverride;
  final Future<bool> Function()? _isDeviceOffline;
  final String Function() _newEventId;
  final Future<String?> Function()? _promptLateReason;

  late final OutboxStore outbox;
  SyncWorker? _syncWorker;
  late final MediaOutboxStore mediaOutbox;
  MediaSyncWorker? _mediaSyncWorker;
  late final MediaBlobStore mediaBlobs;

  SyncWorker get syncWorker => _syncWorker!;

  final visits = <VisitOut>[].obs;
  final openShifts = <OpenShiftOut>[].obs;
  final selectedTab = 'mine'.obs;
  final selected = Rxn<VisitOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = RxnString();

  /// Bumped when outbox changes so Obx rebuilds sync chips.
  final outboxRevision = 0.obs;

  /// Bumped when media outbox changes (form file field progress).
  final mediaOutboxRevision = 0.obs;

  /// fieldId → document_id once media ACK completes (survives until form submit).
  final ackedMediaDocumentIds = <String, String>{}.obs;

  final manualTemplateIdCtrl = TextEditingController();

  /// Template ids submitted this session (until visit refresh returns summaries).
  final submittedTemplateIds = <String>{}.obs;

  bool get isWeb => _location.isWeb;

  bool get canCheckIn => _session.hasPermission(AppPermissions.visitsCheckIn);
  bool get canComplete => _session.hasPermission(AppPermissions.visitsComplete);
  bool get canClaimShifts => _session.hasPermission(AppPermissions.shiftsClaim);
  bool get canRead =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      canCheckIn ||
      canComplete;

  List<VisitFormRequirement> get effectiveFormRequirements =>
      selected.value?.formRequirements ?? const [];

  bool isFormSubmitted(String formTemplateId) {
    if (submittedTemplateIds.contains(formTemplateId)) return true;
    final visit = selected.value;
    if (visit == null) return false;
    return visit.formSubmissions.any((s) => s.formTemplateId == formTemplateId);
  }

  VisitClockSyncUi syncUiFor(String visitId) {
    outboxRevision.value;
    return clockSyncUiFor(
      outbox.pending().where((e) => e.visitId == visitId),
    );
  }

  /// True when this visit has a terminal conflicted outbox row.
  bool hasConflictFor(String visitId) {
    outboxRevision.value;
    return outbox
        .pending()
        .any((e) => e.visitId == visitId && e.isConflict);
  }

  VisitClockSyncUi get selectedSyncUi {
    final id = selected.value?.id;
    if (id == null) return VisitClockSyncUi.none;
    return syncUiFor(id);
  }

  bool get selectedHasConflict {
    final id = selected.value?.id;
    if (id == null) return false;
    return hasConflictFor(id);
  }

  void _bumpOutbox() => outboxRevision.value++;

  @override
  void onInit() {
    super.onInit();
    outbox =
        _outboxOverride ??
        (Get.isRegistered<OutboxStore>()
            ? Get.find<OutboxStore>()
            : OutboxStore(GetStorage()));
    _syncWorker =
        _syncWorkerOverride ??
        (Get.isRegistered<SyncWorker>() ? Get.find<SyncWorker>() : null);
    mediaOutbox =
        _mediaOutboxOverride ??
        (Get.isRegistered<MediaOutboxStore>()
            ? Get.find<MediaOutboxStore>()
            : MediaOutboxStore(GetStorage()));
    mediaBlobs =
        _mediaBlobsOverride ??
        (Get.isRegistered<MediaBlobStore>()
            ? Get.find<MediaBlobStore>()
            : MemoryMediaBlobStore());
    _mediaSyncWorker =
        _mediaSyncWorkerOverride ??
        (Get.isRegistered<MediaSyncWorker>()
            ? Get.find<MediaSyncWorker>()
            : null);
    load();
  }

  /// Bind ACK callbacks when the shared worker was created by [VisitsBinding].
  void attachSyncWorker(SyncWorker worker) {
    _syncWorker = worker;
  }

  void onOutboxAcked(ClockOutboxItem item) {
    _bumpOutbox();
    final selectedId = selected.value?.id;
    if (selectedId != item.visitId) return;
    refreshSelected().then((_) {
      // Skip toast when no navigator overlay (unit tests).
      if (Get.overlayContext == null) return;
      if (item.kind == ClockOutboxKind.checkIn) {
        AppToast.success(
          'Checked in',
          'Visit is now ${selected.value?.status ?? 'checked_in'}.',
        );
      } else {
        AppToast.success('Completed', 'Visit marked completed.');
      }
    });
  }

  void onMediaOutboxAcked(MediaOutboxItem item) {
    mediaOutboxRevision.value++;
    final fieldId = item.fieldId;
    final docId = item.documentId;
    if (fieldId != null && docId != null && docId.isNotEmpty) {
      ackedMediaDocumentIds[fieldId] = docId;
    }
  }

  List<MediaOutboxItem> mediaPendingForVisit(String visitId) {
    mediaOutboxRevision.value;
    return mediaOutbox.pending().where((e) => e.visitId == visitId).toList();
  }

  MediaOutboxItem? mediaPendingForField(String fieldId) {
    mediaOutboxRevision.value;
    final matches =
        mediaOutbox.pending().where((e) => e.fieldId == fieldId).toList();
    if (matches.isEmpty) return null;
    return matches.last;
  }

  /// Enqueue visit evidence for a form file field; never silent-succeeds.
  Future<void> enqueueVisitFormFile({
    required String visitId,
    required String formTemplateId,
    required String fieldId,
    required String filename,
    required String contentType,
    required List<int> bytes,
  }) async {
    if (bytes.isEmpty) {
      errorMessage.value = 'Could not read file bytes.';
      return;
    }
    final clientUploadId = _newEventId();
    final localPath = await mediaBlobs.write(
      clientUploadId: clientUploadId,
      bytes: bytes,
      filename: filename,
    );
    final item = MediaOutboxItem(
      clientUploadId: clientUploadId,
      ownerType: 'visit',
      ownerId: visitId,
      filename: filename,
      contentType: contentType,
      sizeBytes: bytes.length,
      localPath: localPath,
      createdAtIso: DateTime.now().toUtc().toIso8601String(),
      category: 'other',
      visitId: visitId,
      formTemplateId: formTemplateId,
      fieldId: fieldId,
    );
    await mediaOutbox.append(item);
    mediaOutboxRevision.value++;
    ackedMediaDocumentIds.remove(fieldId);
    final worker = _mediaSyncWorker;
    if (worker != null) {
      await worker.flush();
    }
  }

  Future<void> retryMediaUploads() async {
    final worker = _mediaSyncWorker;
    if (worker != null) {
      await worker.flush();
    }
  }

  /// SyncWorker / immediate push marked a terminal conflict — drop optimistic
  /// checked_in/completed so the UI does not claim a status the server denied.
  void onOutboxConflict(ClockOutboxItem item) {
    _bumpOutbox();
    _revertOptimisticStatus(item);
  }

  Future<void> dismissConflictForSelected() async {
    final id = selected.value?.id;
    if (id == null) return;
    final conflicts = outbox
        .pending()
        .where((e) => e.visitId == id && e.isConflict)
        .toList(growable: false);
    for (final item in conflicts) {
      await outbox.dismissConflict(item.clientEventId);
    }
    _bumpOutbox();
  }

  void _revertOptimisticStatus(ClockOutboxItem item) {
    VisitOut revert(VisitOut v) {
      if (item.kind == ClockOutboxKind.checkIn) {
        return v.copyWith(status: 'scheduled', clearCompletedAt: true);
      }
      return v.copyWith(status: 'checked_in', clearCompletedAt: true);
    }

    final sel = selected.value;
    if (sel != null && sel.id == item.visitId) {
      selected.value = revert(sel);
    }
    final idx = visits.indexWhere((v) => v.id == item.visitId);
    if (idx >= 0) {
      visits[idx] = revert(visits[idx]);
    }
  }

  /// After staff force-accept/discard, server status may already match the
  /// punch — clear local conflict rows so completes are not blocked forever.
  Future<void> _dismissConflictsResolvedByServer(VisitOut visit) async {
    final conflicts = outbox
        .pending()
        .where((e) => e.visitId == visit.id && e.isConflict)
        .toList(growable: false);
    if (conflicts.isEmpty) return;
    var changed = false;
    for (final item in conflicts) {
      final resolved = switch (item.kind) {
        ClockOutboxKind.checkIn => visit.isCheckedIn || visit.isCompleted,
        ClockOutboxKind.complete => visit.isCompleted,
      };
      if (!resolved) continue;
      await outbox.dismissConflict(item.clientEventId);
      changed = true;
    }
    if (changed) _bumpOutbox();
  }

  @override
  void onClose() {
    manualTemplateIdCtrl.dispose();
    super.onClose();
  }

  Future<void> selectTab(String tab) async {
    selectedTab.value = tab;
    if (tab == 'open') {
      await loadOpenShifts();
    } else {
      await load();
    }
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing visits.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).toUtc();
      final to = from.add(const Duration(days: 14));
      final list = await _repository.listVisits(from: from, to: to);
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      visits.assignAll(list);
    } on AppFailure catch (e) {
      if (_isTenantMissingError(e)) {
        visits.clear();
      } else {
        errorMessage.value = e.message;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadOpenShifts() async {
    if (!canClaimShifts) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).toUtc();
      final to = from.add(const Duration(days: 14));
      final list = await _shiftsRepository.listOpenShifts(from: from, to: to);
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      openShifts.assignAll(list);
    } on AppFailure catch (e) {
      if (_isTenantMissingError(e)) {
        openShifts.clear();
      } else {
        errorMessage.value = e.message;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> claimShift(String shiftId) async {
    if (!canClaimShifts) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final shift = await _shiftsRepository.claimShift(shiftId);
      openShifts.removeWhere((s) => s.id == shiftId);
      final assignment = shift.assignments.last;
      final visit = await _repository.getVisit(assignment.visitId);
      final idx = visits.indexWhere((v) => v.id == visit.id);
      if (idx >= 0) {
        visits[idx] = visit;
      } else {
        visits.add(visit);
        visits.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      }
      selectedTab.value = 'mine';
      await openDetail(visit);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openDetail(VisitOut visit) async {
    selected.value = visit;
    submittedTemplateIds.clear();
    Get.toNamed(AppRoutes.contractorVisitDetail, arguments: visit);
    await refreshSelected();
  }

  void hydrateFromArgs() {
    final arg = Get.arguments;
    if (arg is VisitOut) selected.value = arg;
  }

  /// Visit id from hydrated selection or route args (VisitOut or String).
  String? get resolvedVisitId =>
      selected.value?.id ?? _visitIdFromArgs(Get.arguments);

  Future<void> refreshSelected() async {
    final id = resolvedVisitId;
    if (id == null) return;
    isRefreshing.value = true;
    try {
      final visit = await _repository.getVisit(id);
      selected.value = visit;
      final idx = visits.indexWhere((v) => v.id == id);
      if (idx >= 0) {
        visits[idx] = visit;
      }
      await _dismissConflictsResolvedByServer(visit);
    } on AppFailure catch (e) {
      if (!_isRetryableFailure(e) || syncUiFor(id) == VisitClockSyncUi.none) {
        errorMessage.value = e.message;
      }
    } finally {
      isRefreshing.value = false;
    }
  }

  Future<void> submitForm(
    VisitFormRequirement req, {
    required Map<String, dynamic> payloadJson,
  }) async {
    final visit = selected.value;
    if (visit == null) return;
    if (payloadJson.isEmpty) {
      errorMessage.value = 'Form payload is empty.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.submitForm(
        visitId: visit.id,
        body: VisitFormSubmitRequest(
          formTemplateId: req.formTemplateId,
          payloadJson: payloadJson,
        ),
      );
      submittedTemplateIds.add(req.formTemplateId);
      await refreshSelected();
      AppToast.success('Form submitted', req.name ?? req.formTemplateId);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleTask(VisitTaskOut task) async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.patchTask(
        visitId: visit.id,
        taskId: task.id,
        isDone: !task.isDone,
      );
      final tasks = visit.tasks
          .map((t) => t.id == updated.id ? updated : t)
          .toList(growable: false);
      selected.value = visit.copyWith(tasks: tasks);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> retryPendingSync() async {
    final worker = _syncWorker;
    if (worker != null) await worker.flush();
  }

  Future<void> checkIn() async {
    final visit = selected.value;
    if (visit == null) return;
    if (isWeb) {
      errorMessage.value = VisitLocationService.webBlockedMessage;
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    String? clientEventId;
    try {
      final tapTime = DateTime.now().toUtc();
      String? lateReason;
      if (isLateCheckIn(
        scheduledStart: visit.scheduledStart,
        tapTime: tapTime,
      )) {
        lateReason = await (_promptLateReason?.call() ?? _showLateReasonDialog());
        if (lateReason == null || lateReason.isEmpty) {
          return;
        }
      }
      final gps = await _location.tryGps();
      clientEventId = _newEventId();
      final offline = await _resolveDeviceOffline();
      final item = ClockOutboxItem(
        clientEventId: clientEventId,
        visitId: visit.id,
        kind: ClockOutboxKind.checkIn,
        tapTimeIso: tapTime.toIso8601String(),
        locationStatus: gps.status,
        locationFailReason: gps.failReason,
        lat: gps.body?.lat,
        lng: gps.body?.lng,
        accuracyM: gps.body?.accuracyM,
        deviceOffline: offline,
        lateReasonCode: lateReason,
      );
      await outbox.append(item);
      _bumpOutbox();
      selected.value = visit.copyWith(status: 'checked_in');

      final acked = await _tryPushNow(item);
      if (acked) {
        await outbox.ack(clientEventId);
        _bumpOutbox();
        await refreshSelected();
        AppToast.success(
          'Checked in',
          'Visit is now ${selected.value?.status ?? 'checked_in'}.',
        );
      }
      // else: leave Pending — no success toast without ACK
    } on AppFailure catch (e) {
      if (clientEventId != null) {
        await outbox.ack(clientEventId);
        _bumpOutbox();
      }
      selected.value = visit;
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<String?> _showLateReasonDialog() async {
    if (Get.testMode || Get.overlayContext == null) {
      return null;
    }
    return Get.dialog<String>(
      SimpleDialog(
        title: const Text('Why are you checking in late?'),
        children: [
          for (final code in lateCheckInReasonCodes)
            SimpleDialogOption(
              onPressed: () => Get.back(result: code),
              child: Text(lateCheckInReasonLabels[code] ?? code),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> complete() async {
    final visit = selected.value;
    if (visit == null) return;
    if (isWeb) {
      errorMessage.value = VisitLocationService.webBlockedMessage;
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    String? clientEventId;
    try {
      final gps = await _location.tryGps();
      clientEventId = _newEventId();
      final tapTime = DateTime.now().toUtc();
      final offline = await _resolveDeviceOffline();
      final item = ClockOutboxItem(
        clientEventId: clientEventId,
        visitId: visit.id,
        kind: ClockOutboxKind.complete,
        tapTimeIso: tapTime.toIso8601String(),
        locationStatus: gps.status,
        locationFailReason: gps.failReason,
        lat: gps.body?.lat,
        lng: gps.body?.lng,
        accuracyM: gps.body?.accuracyM,
        deviceOffline: offline,
      );
      await outbox.append(item);
      _bumpOutbox();
      selected.value = visit.copyWith(
        status: 'completed',
        completedAt: tapTime,
      );

      final acked = await _tryPushNow(item);
      if (acked) {
        await outbox.ack(clientEventId);
        _bumpOutbox();
        await refreshSelected();
        AppToast.success('Completed', 'Visit marked completed.');
      }
    } on AppFailure catch (e) {
      if (clientEventId != null) {
        await outbox.ack(clientEventId);
        _bumpOutbox();
      }
      selected.value = visit;
      if (e.code == 'forms_incomplete' ||
          e.code == 'required_forms_incomplete') {
        errorMessage.value =
            effectiveFormRequirements.isEmpty
                ? 'Required forms are incomplete. Submit the progress form '
                    'listed above (or ask staff to attach form requirements '
                    'to the visit), then Complete again.'
                : e.message;
      } else {
        errorMessage.value = e.message;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  /// Immediate push; returns true on ACK. Network failures return false.
  /// Terminal clock failures report a sync conflict (same as [SyncWorker]).
  /// Form-requirement failures are rethrown so the caller can clear optimistic
  /// state and show the forms UI.
  Future<bool> _tryPushNow(ClockOutboxItem item) async {
    try {
      final body = gpsBodyFromOutbox(item);
      if (item.kind == ClockOutboxKind.checkIn) {
        await _repository.checkIn(
          id: item.visitId,
          body: body,
          idempotencyKey: item.clientEventId,
        );
      } else {
        await _repository.complete(
          id: item.visitId,
          body: body,
          idempotencyKey: item.clientEventId,
        );
      }
      return true;
    } on AppFailure catch (e) {
      if (_isRetryableFailure(e)) {
        // Leave Pending without lastError so UI stays "Pending sync".
        return false;
      }
      if (e.code == 'forms_incomplete' ||
          e.code == 'required_forms_incomplete') {
        rethrow;
      }
      final failureClass = classifySyncFailure(
        statusCode: e.statusCode,
        detail: e.code,
      );
      if (failureClass == SyncFailureClass.terminal) {
        final detail =
            (e.code.isNotEmpty && e.code != 'unknown') ? e.code : e.message;
        try {
          await _repository.reportSyncConflict(
            visitId: item.visitId,
            clientEventId: item.clientEventId,
            kind: item.apiKind,
            failureDetail: detail,
            payloadJson: item.toConflictPayloadJson(),
          );
          await outbox.markConflict(item.clientEventId, detail);
          onOutboxConflict(item);
        } on AppFailure {
          await outbox.markAttempt(item.clientEventId, e.message);
          _bumpOutbox();
        } catch (_) {
          await outbox.markAttempt(item.clientEventId, e.message);
          _bumpOutbox();
        }
        return false;
      }
      rethrow;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _resolveDeviceOffline() async {
    final check = _isDeviceOffline;
    if (check != null) return check();
    try {
      final results = await Connectivity().checkConnectivity();
      return results.isEmpty ||
          results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  static bool _isRetryableFailure(AppFailure e) {
    if (e.code == 'network_error' || e.code == 'cors_or_network') return true;
    final code = e.statusCode;
    if (code == null) return true;
    return code >= 500;
  }
}

String? _visitIdFromArgs(Object? arg) {
  if (arg is VisitOut) return arg.id;
  if (arg is String && arg.isNotEmpty) return arg;
  return null;
}

bool _isTenantMissingError(AppFailure e) {
  final msg = e.message.toLowerCase();
  final code = e.code.toLowerCase();
  return msg.contains('tenant_id') ||
      msg.contains('tenant id') ||
      code.contains('tenant') ||
      msg.contains('not engaged') ||
      msg.contains('no engagement');
}
