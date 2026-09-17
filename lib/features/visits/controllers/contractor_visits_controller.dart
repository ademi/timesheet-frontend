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
import '../sync/sync_worker.dart';

enum VisitClockSyncUi { none, pending, failed }

class ContractorVisitsController extends GetxController {
  ContractorVisitsController({
    required VisitsRepository repository,
    required ShiftsRepository shiftsRepository,
    required SessionService session,
    VisitLocationService location = const VisitLocationService(),
    OutboxStore? outbox,
    SyncWorker? syncWorker,
    Future<bool> Function()? isDeviceOffline,
    String Function()? newEventId,
  }) : _repository = repository,
       _shiftsRepository = shiftsRepository,
       _session = session,
       _location = location,
       _outboxOverride = outbox,
       _syncWorkerOverride = syncWorker,
       _isDeviceOffline = isDeviceOffline,
       _newEventId = newEventId ?? const Uuid().v4;

  final VisitsRepository _repository;
  final ShiftsRepository _shiftsRepository;
  final SessionService _session;
  final VisitLocationService _location;
  final OutboxStore? _outboxOverride;
  final SyncWorker? _syncWorkerOverride;
  final Future<bool> Function()? _isDeviceOffline;
  final String Function() _newEventId;

  late final OutboxStore outbox;
  SyncWorker? _syncWorker;

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
    final items =
        outbox.pending().where((e) => e.visitId == visitId).toList();
    if (items.isEmpty) return VisitClockSyncUi.none;
    if (items.any((e) => e.lastError != null)) return VisitClockSyncUi.failed;
    return VisitClockSyncUi.pending;
  }

  VisitClockSyncUi get selectedSyncUi {
    final id = selected.value?.id;
    if (id == null) return VisitClockSyncUi.none;
    return syncUiFor(id);
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
    // Ensure injected / found worker notifies this controller.
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
      final gps = await _location.tryGps();
      clientEventId = _newEventId();
      final tapTime = DateTime.now().toUtc();
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
  /// Non-retryable [AppFailure] is rethrown (caller removes outbox item).
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
