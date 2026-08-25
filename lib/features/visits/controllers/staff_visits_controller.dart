import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../core/time/tenant_civil_time.dart';
import '../../../shared/utils/name_sort.dart';
import '../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../clients/utils/client_quick_facts.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../jobs/data/models/job_models.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../billing/data/models/billing_models.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../utils/visit_billing_utils.dart';
import '../data/models/roster_overlay_models.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';
import '../roster/roster_grid_model.dart';
import '../roster/support_filter.dart';

String assignAvailabilityLabel({
  required String contractorId,
  required DateTime day,
  required DateTime shiftStart,
  required DateTime shiftEnd,
  required RosterOverlayOut overlay,
  required List<ShiftOut> shifts,
}) {
  final dayLocal = day.toLocal();
  final civil = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  for (final c in overlay.contractors) {
    if (c.contractorId != contractorId) continue;
    for (final leave in c.leave) {
      final leaveStart = leave.startDate.toLocal();
      final leaveEnd = leave.endDate.toLocal();
      final start = DateTime(
        leaveStart.year,
        leaveStart.month,
        leaveStart.day,
      );
      final end = DateTime(
        leaveEnd.year,
        leaveEnd.month,
        leaveEnd.day,
      );
      if (!civil.isBefore(start) && !civil.isAfter(end)) return 'Leave';
    }
  }
  for (final s in shifts) {
    if (s.status == 'cancelled') continue;
    final overlaps =
        s.scheduledStart.isBefore(shiftEnd) &&
        s.scheduledEnd.isAfter(shiftStart);
    if (!overlaps) continue;
    for (final a in s.assignments) {
      if (a.status == 'active' && a.contractorId == contractorId) {
        return 'Busy';
      }
    }
  }
  return 'Free';
}

class StaffVisitsController extends GetxController {
  StaffVisitsController({
    required VisitsRepository repository,
    required ShiftsRepository shiftsRepository,
    required JobsRepository jobsRepository,
    required EngagementsRepository engagementsRepository,
    required ClientsRepository clientsRepository,
    required SessionService session,
    PayrollRepository? payroll,
  }) : _repository = repository,
       _shiftsRepository = shiftsRepository,
       _jobsRepository = jobsRepository,
       _engagementsRepository = engagementsRepository,
       _clientsRepository = clientsRepository,
       _session = session,
       _payroll = payroll;

  final VisitsRepository _repository;
  final ShiftsRepository _shiftsRepository;
  final JobsRepository _jobsRepository;
  final EngagementsRepository _engagementsRepository;
  final ClientsRepository _clientsRepository;
  final SessionService _session;
  final PayrollRepository? _payroll;

  final shifts = <ShiftOut>[].obs;
  final jobs = <JobOut>[].obs;
  final engagements = <EngagementOut>[].obs;
  final selected = Rxn<VisitOut>();
  final selectedShift = Rxn<ShiftOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isRefreshing = false.obs;
  final isFillingHorizon = false.obs;
  final errorMessage = RxnString();
  final overlay = Rxn<RosterOverlayOut>();
  final overlayWarning = RxnString();

  final editingVisitSupportItemCode = RxnString();
  final editingVisitSupportItemName = RxnString();
  final editingTaskSupportCodes = <String, String?>{}.obs;
  final editingTaskSupportNames = <String, String?>{}.obs;
  final editingPriceTierOverride = RxnString();
  final priceTierEditBlocked = false.obs;
  final editingTaskBillableMinutes = <String, int?>{}.obs;
  final participantNdisNumber = RxnString();
  final isLoadingParticipantNdis = false.obs;

  /// Board range: aligned to tenant civil week when timezone is available.
  final rangeStart = DateTime.now().obs;
  final tenantTimezone = ''.obs;
  bool _tenantTimezoneLoaded = false;
  final jobIdFilter = ''.obs;
  final clientIdFilter = ''.obs;
  /// Default Live (published) so draft/cancelled do not clutter the board.
  final statusFilter = 'published'.obs;
  bool pendingCreateShift = false;
  bool skipHorizonOnce = false;
  String? pendingClientIdFilter;

  bool _horizonInFlight = false;
  DateTime? _horizonLastAttempt;

  @visibleForTesting
  int horizonSnackCount = 0;

  bool get canManage => _session.hasPermission(AppPermissions.shiftsManage);
  bool get canEditVisitSupportItem {
    final visit = selected.value;
    return visit != null &&
        canManage &&
        visit.isScheduled &&
        visit.paymentStatus == 'unpaid';
  }

  bool get canEditVisitPriceTier {
    final visit = selected.value;
    return visit != null &&
        canManage &&
        !visit.isCancelled &&
        !priceTierEditBlocked.value;
  }

  bool get canEditVisitTaskBilling => canEditVisitPriceTier;

  bool get taskMinutesExceedVisitWarning {
    final visit = selected.value;
    if (visit == null) return false;
    return taskMinutesExceedVisitDuration(visit);
  }

  int get visitScheduledMinutes {
    final visit = selected.value;
    if (visit == null) return 0;
    return visitScheduledDurationMinutes(visit);
  }

  int get codedTaskMinutesTotal {
    final visit = selected.value;
    if (visit == null) return 0;
    return codedTaskBillableMinutesTotal(visit);
  }

  bool get hasCodedTasks {
    final visit = selected.value;
    if (visit == null) return false;
    return visitHasCodedTasks(visit);
  }
  bool get canRead =>
      _session.hasPermission(AppPermissions.shiftsRead) ||
      _session.hasPermission(AppPermissions.shiftsManage) ||
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  List<EngagementOut> get assignableEngagements => sortedByName(
        engagements.where((e) => e.isActive || e.isApproved || e.isPendingDocs),
        (e) => e.displayName,
      );

  /// Unique clients from jobs + loaded shifts for the board filter.
  List<({String id, String name})> get clientFilterOptions {
    final byId = <String, String>{};
    for (final job in jobs) {
      final id = job.clientId?.trim();
      if (id == null || id.isEmpty) continue;
      byId.putIfAbsent(id, () => (job.clientName?.trim().isNotEmpty == true)
          ? job.clientName!.trim()
          : id);
    }
    for (final shift in shifts) {
      final id = shift.clientId?.trim();
      if (id == null || id.isEmpty) continue;
      byId.putIfAbsent(id, () => (shift.clientName?.trim().isNotEmpty == true)
          ? shift.clientName!.trim()
          : id);
    }
    final list = byId.entries
        .map((e) => (id: e.key, name: e.value))
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  RosterGrid get grid {
    final start = DateTime(
      rangeStart.value.year,
      rangeStart.value.month,
      rangeStart.value.day,
    );
    final people = assignableEngagements
        .map(
          (e) => RosterPerson(
            contractorId: e.contractorId,
            displayName:
                (e.contractorName?.trim().isNotEmpty == true)
                    ? e.contractorName!.trim()
                    : 'Worker',
          ),
        )
        .toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    return buildRosterGrid(
      rangeStart: start,
      dayCount: 7,
      shifts: shifts.toList(),
      people: people,
      overlay: overlay.value ?? const RosterOverlayOut(contractors: []),
      clientIdFilter:
          clientIdFilter.value.isEmpty ? null : clientIdFilter.value,
    );
  }

  DateTime get _fromUtc =>
      tenantCivilDateStartUtc(rangeStart.value, _effectiveTenantTimezone);

  DateTime get _toUtc => tenantCivilDateStartUtc(
        rangeStart.value.add(const Duration(days: 7)),
        _effectiveTenantTimezone,
      );

  String? get _effectiveTenantTimezone {
    final sessionTz = _session.tenantTimezone.value?.trim();
    if (sessionTz != null && sessionTz.isNotEmpty) return sessionTz;
    final tz = tenantTimezone.value.trim();
    return tz.isEmpty ? null : tz;
  }

  /// Rolling 14-day fill window from tenant civil start of today (D15).
  DateTime get _horizonFromUtc => tenantHorizonWindowUtc(
        DateTime.now().toUtc(),
        _effectiveTenantTimezone,
      ).from;

  DateTime get _horizonToUtc => tenantHorizonWindowUtc(
        DateTime.now().toUtc(),
        _effectiveTenantTimezone,
      ).to;

  @override
  void onInit() {
    super.onInit();
    applyRouteArgs();
  }

  void applyRouteArgs() {
    final args = Get.arguments;
    if (args is Map) {
      final v = args['visit'];
      if (v is VisitOut) {
        selected.value = v;
        _syncSupportItemEditors(v);
      }
      final shift = args['shift'];
      if (shift is ShiftOut) selectedShift.value = shift;
      if (args['job_id'] != null) {
        jobIdFilter.value = args['job_id'].toString();
      }
      if (args['skipHorizonOnce'] == true) skipHorizonOnce = true;
      if (args['client_id'] != null) {
        pendingClientIdFilter = args['client_id'].toString();
      }
      pendingCreateShift = args['create'] == true;
      return;
    }
    if (args is VisitOut) {
      selected.value = args;
      _syncSupportItemEditors(args);
    }
    if (args is ShiftOut) selectedShift.value = args;
  }

  bool consumePendingCreateShift() {
    if (!pendingCreateShift) return false;
    pendingCreateShift = false;
    return true;
  }

  /// Loads tenant IANA timezone once (session, then settings, then payroll).
  Future<void> loadTenantTimezone() async {
    if (_tenantTimezoneLoaded) return;
    _tenantTimezoneLoaded = true;
    final sessionTz = _session.tenantTimezone.value?.trim();
    if (sessionTz != null && sessionTz.isNotEmpty) {
      tenantTimezone.value = sessionTz;
      return;
    }
    if (Get.isRegistered<StaffTenantSettingsController>()) {
      final tz = Get.find<StaffTenantSettingsController>().tenant.value?.timezone;
      if (tz != null && tz.trim().isNotEmpty) {
        tenantTimezone.value = tz.trim();
        return;
      }
    }
    final id = _session.tenantId.value;
    if (id == null || id.isEmpty || _payroll == null) return;
    try {
      final t = await _payroll.getTenant(id);
      tenantTimezone.value = t.timezone?.trim() ?? '';
    } catch (_) {
      // Roster still works on device-local civil days.
    }
  }

  /// Sets [rangeStart] to Monday 00:00 of the tenant civil week containing [utcNow].
  void alignRangeToTenantWeek(DateTime utcNow) {
    final tz = tenantTimezone.value.trim();
    rangeStart.value = startOfTenantWeekMonday(
      utcNow,
      tz.isEmpty ? null : tz,
    );
  }

  /// Only entry point for roster board list fetch.
  Future<void> ensureBoardLoaded() async {
    await loadTenantTimezone();
    alignRangeToTenantWeek(DateTime.now().toUtc());
    await loadJobs();
    await loadEngagements();
    await load();
    if (skipHorizonOnce) {
      skipHorizonOnce = false;
      return;
    }
    unawaited(_fillHorizon());
  }

  Future<void> _fillHorizon() async {
    if (_horizonInFlight) return;
    if (!_session.hasPermission(AppPermissions.jobsManage)) return;
    final last = _horizonLastAttempt;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 60)) {
      return;
    }
    _horizonInFlight = true;
    isFillingHorizon.value = true;
    _horizonLastAttempt = DateTime.now();
    try {
      final result = await _jobsRepository.ensureHorizon(
        HorizonRequest(from: _horizonFromUtc, to: _horizonToUtc),
      );
      final created = result.createdShiftIds.length;
      if (created > 0) {
        await load();
        notifyRosterUpdated(created);
      }
    } on AppFailure catch (_) {
      // D17: list already painted — do not set errorMessage. 429 toast is mapped.
    } finally {
      _horizonInFlight = false;
      isFillingHorizon.value = false;
    }
  }

  void notifyRosterUpdated(int created) {
    if (created <= 0) return;
    horizonSnackCount++;
    if (Get.testMode) return;
    Get.snackbar(
      'Roster updated',
      '$created new time${created == 1 ? '' : 's'} added.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.primary,
      colorText: AppColors.onPrimary,
    );
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing shifts.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    overlayWarning.value = null;
    Future<RosterOverlayOut?>? overlayFuture;
    try {
      final from = _fromUtc;
      final to = _toUtc;
      // D20: isolate overlay failure from shifts — soft banner only.
      final shiftsFuture = _shiftsRepository.listShifts(
        from: from,
        to: to,
        jobId:
            jobIdFilter.value.trim().isEmpty ? null : jobIdFilter.value.trim(),
      );
      overlayFuture = () async {
        try {
          return await _repository.fetchRosterOverlay(from: from, to: to);
        } catch (_) {
          overlayWarning.value = 'Leave/availability unavailable';
          return null;
        }
      }();
      final listRaw = await shiftsFuture;
      final status = statusFilter.value.trim();
      final list =
          status.isEmpty
              ? listRaw
              : listRaw
                  .where((s) => s.status == status)
                  .toList(growable: false);
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      shifts.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      // Paint shifts before waiting on overlay (D20 / paint-first).
      isLoading.value = false;
    }
    if (overlayFuture != null) {
      overlay.value =
          await overlayFuture ?? const RosterOverlayOut(contractors: []);
    }
  }

  Future<void> loadJobs() async {
    try {
      jobs.assignAll(await _jobsRepository.listJobs());
      _applyPendingClientFilter();
    } catch (_) {
      // Optional filter list.
    }
  }

  void _applyPendingClientFilter() {
    final clientId = pendingClientIdFilter;
    if (clientId == null || clientId.isEmpty) return;
    clientIdFilter.value = clientId;
    pendingClientIdFilter = null;
  }

  Future<void> loadEngagements() async {
    try {
      engagements.assignAll(await _engagementsRepository.listTenantEngagements());
    } catch (_) {
      // Assign picker may be empty without engagements.read.
    }
  }

  void setJobFilter(String? jobId) {
    jobIdFilter.value = jobId ?? '';
    load();
  }

  void setClientFilter(String? clientId) {
    clientIdFilter.value = clientId ?? '';
    // Always drop support selection on client change — a previous client's
    // jobId must not pin the shift query when switching between clients
    // that both show the support sub-filter (D3).
    if (jobIdFilter.value.isNotEmpty) {
      jobIdFilter.value = '';
      load();
    }
  }

  /// Whether the per-support sub-filter should show for the current client (D3).
  bool get showSupportFilter => shouldShowSupportFilter(
        jobs,
        clientId: clientIdFilter.value.isEmpty ? null : clientIdFilter.value,
      );

  /// Open supports for the currently selected client (empty when none selected).
  List<JobOut> get supportsForSelectedClient => clientIdFilter.value.isEmpty
      ? const <JobOut>[]
      : jobsForClientFilter(jobs, clientId: clientIdFilter.value);

  void shiftRange(int days) {
    rangeStart.value = rangeStart.value.add(Duration(days: days));
    unawaited(load());
  }

  void setStatusFilter(String? status) {
    statusFilter.value = status ?? '';
    load();
  }

  Future<void> openShiftDetail(ShiftOut shift) async {
    selectedShift.value = shift;
    Get.toNamed(AppRoutes.staffShiftDetail, arguments: shift);
    await refreshSelectedShift();
  }

  Future<void> openShiftFromTile(RosterTile tile) async {
    ShiftOut? match;
    for (final shift in shifts) {
      if (shift.id == tile.shiftId) {
        match = shift;
        break;
      }
    }
    if (match == null) return;
    await openShiftDetail(match);
  }

  Future<void> refreshSelectedShift() async {
    final id =
        selectedShift.value?.id ??
        (Get.arguments is ShiftOut ? (Get.arguments as ShiftOut).id : null);
    if (id == null) return;
    isRefreshing.value = true;
    try {
      selectedShift.value = await _shiftsRepository.getShift(id);
      final idx = shifts.indexWhere((s) => s.id == id);
      if (idx >= 0 && selectedShift.value != null) {
        shifts[idx] = selectedShift.value!;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isRefreshing.value = false;
    }
  }

  void hydrateShiftFromArgs() {
    final arg = Get.arguments;
    if (arg is ShiftOut) {
      selectedShift.value = arg;
      return;
    }
    if (arg is Map && arg['shift'] is ShiftOut) {
      selectedShift.value = arg['shift'] as ShiftOut;
    }
  }

  Future<void> publishSelectedShift() async {
    final shift = selectedShift.value;
    if (shift == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      selectedShift.value = await _shiftsRepository.publishShift(shift.id);
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> confirmAssignAnyway() async {
    if (Get.testMode) return true;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Assign anyway?'),
        content: const Text(
          'This worker is marked Leave or Busy for this time. Assign anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
    return result == true;
  }

  String availabilityLabelForAssign({
    required String contractorId,
    required ShiftOut shift,
  }) {
    final day = DateTime(
      shift.scheduledStart.year,
      shift.scheduledStart.month,
      shift.scheduledStart.day,
    );
    return assignAvailabilityLabel(
      contractorId: contractorId,
      day: day,
      shiftStart: shift.scheduledStart,
      shiftEnd: shift.scheduledEnd,
      overlay: overlay.value ?? const RosterOverlayOut(contractors: []),
      shifts: shifts.toList(growable: false),
    );
  }

  Future<void> assignSelectedShift(
    String contractorId, {
    bool skipConfirm = false,
  }) async {
    final shift = selectedShift.value;
    if (shift == null) return;
    if (!skipConfirm) {
      final label = availabilityLabelForAssign(
        contractorId: contractorId,
        shift: shift,
      );
      if (label != 'Free' && !await confirmAssignAnyway()) return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      selectedShift.value = await _shiftsRepository.assignShift(
        shiftId: shift.id,
        contractorId: contractorId,
      );
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> cancelSelectedShift() async {
    final shift = selectedShift.value;
    if (shift == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      selectedShift.value = await _shiftsRepository.cancelShift(shift.id);
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  /// Staff release (unassign) — opens a hole and notifies eligible contractors.
  @visibleForTesting
  String? lastReleaseSnack;

  Future<bool> confirmRelease(String workerName) async {
    if (Get.testMode) return true;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Release worker?'),
        content: Text(
          'Release $workerName? Hole opens for claim and eligible workers are notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Release'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> releaseAssignment({
    required String shiftId,
    required String contractorId,
    String workerName = 'Worker',
    bool skipConfirm = false,
  }) async {
    if (!canManage) return;
    if (!skipConfirm && !await confirmRelease(workerName)) return;
    isSaving.value = true;
    errorMessage.value = null;
    lastReleaseSnack = null;
    try {
      final updated = await _shiftsRepository.unassignShift(
        shiftId,
        contractorId,
      );
      if (selectedShift.value?.id == shiftId) {
        selectedShift.value = updated;
      }
      await load();
      lastReleaseSnack = 'Hole opened — eligible workers notified.';
      if (!Get.testMode) {
        Get.snackbar(
          'Released',
          lastReleaseSnack!,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
          colorText: AppColors.onPrimary,
        );
      }
    } on AppFailure catch (e) {
      final msg = e.code == 'invalid_visit_status'
          ? 'Already checked in — cancel the shift first.'
          : e.message;
      errorMessage.value = msg;
      lastReleaseSnack = msg;
      if (!Get.testMode) {
        Get.snackbar(
          'Could not release',
          msg,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.error,
          colorText: AppColors.onPrimary,
        );
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> copyTile({
    required ShiftOut source,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _shiftsRepository.createShift(
        ShiftCreateRequest(
          jobId: source.jobId,
          scheduledStart: start.toUtc(),
          scheduledEnd: end.toUtc(),
          requiredSlots: source.requiredSlots,
          status: 'published',
        ),
      );
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> cancelThisOccurrence(String shiftId) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _shiftsRepository.cancelShift(shiftId);
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  /// Split recurrence from this occurrence onward (this and future).
  Future<void> editThisAndFuture({
    required ShiftOut tile,
    required List<TimeWindow> windows,
    String? contractorId,
  }) async {
    if (!canManage) return;
    final ruleId = tile.recurrenceRuleId;
    if (ruleId == null || ruleId.isEmpty) {
      errorMessage.value = 'This shift is not part of a pattern.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final civil = tenantCivilFromUtc(tile.scheduledStart.toUtc(), _effectiveTenantTimezone);
      final fromDate = DateTime(civil.year, civil.month, civil.day);
      final horizon = tenantHorizonWindowFromCivilDate(
        fromDate,
        _effectiveTenantTimezone,
      );
      await _jobsRepository.splitRecurrenceFrom(
        jobId: tile.jobId,
        ruleId: ruleId,
        body: SplitRecurrenceRequest(
          fromDate: fromDate,
          timeWindows: windows,
          contractorId: contractorId,
          requiredSlots: tile.requiredSlots,
          horizonFrom: horizon.from,
          horizonTo: horizon.to,
        ),
      );
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> createShift({
    required String jobId,
    required DateTime start,
    required DateTime end,
    required int requiredSlots,
    bool publish = false,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _shiftsRepository.createShift(
        ShiftCreateRequest(
          jobId: jobId,
          scheduledStart: start,
          scheduledEnd: end,
          requiredSlots: requiredSlots,
          status: publish ? 'published' : 'draft',
        ),
      );
      // Refresh roster after the dialog closes so a slow list fetch cannot block UI.
      load();
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Client-first booking: ensure the client's ongoing support exists, then
  /// create a shift against it. The user never picks a "job" (D9). Errors from
  /// ensure (e.g. `site_or_branch_required`, D10) surface via [errorMessage].
  Future<bool> bookOneForClient({
    required String clientId,
    required DateTime start,
    required DateTime end,
    int requiredSlots = 1,
    bool publish = true,
  }) async {
    if (isSaving.value) return false;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final support = await _jobsRepository.ensureOngoingSupport(clientId);
      await _shiftsRepository.createShift(
        ShiftCreateRequest(
          jobId: support.id,
          scheduledStart: start,
          scheduledEnd: end,
          requiredSlots: requiredSlots,
          status: publish ? 'published' : 'draft',
        ),
      );
      // Refresh roster after the dialog closes so a slow list fetch cannot block UI.
      load();
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openAssignmentVisit(String visitId) async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final visit = await _repository.getVisit(visitId);
      await openDetail(visit);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openDetail(VisitOut visit) async {
    selected.value = visit;
    _syncSupportItemEditors(visit);
    Get.toNamed(AppRoutes.staffVisitDetail, arguments: visit);
    await refreshSelected();
  }

  String? _clientIdForVisit(VisitOut visit) {
    for (final job in jobs) {
      if (job.id == visit.jobId) return job.clientId;
    }
    for (final shift in shifts) {
      if (shift.jobId == visit.jobId && shift.clientId != null) {
        return shift.clientId;
      }
    }
    return null;
  }

  Future<void> _loadParticipantNdis(VisitOut visit) async {
    final clientId = _clientIdForVisit(visit);
    if (clientId == null || clientId.isEmpty) {
      participantNdisNumber.value = null;
      return;
    }
    isLoadingParticipantNdis.value = true;
    try {
      final bundle = await _clientsRepository.getClientProfile(clientId);
      participantNdisNumber.value = ndisFromFacts(bundle.facts);
    } catch (_) {
      participantNdisNumber.value = null;
    } finally {
      isLoadingParticipantNdis.value = false;
    }
  }

  Future<void> refreshSelected() async {
    final id =
        selected.value?.id ??
        (Get.arguments is VisitOut ? (Get.arguments as VisitOut).id : null);
    if (id == null) return;
    isRefreshing.value = true;
    try {
      final visit = await _repository.getVisit(id);
      selected.value = visit;
      _syncSupportItemEditors(visit);
      await _loadParticipantNdis(visit);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isRefreshing.value = false;
    }
  }

  void hydrateFromArgs() {
    final arg = Get.arguments;
    if (arg is VisitOut) {
      selected.value = arg;
      _syncSupportItemEditors(arg);
      _loadParticipantNdis(arg);
      return;
    }
    if (arg is Map && arg['visit'] is VisitOut) {
      final visit = arg['visit'] as VisitOut;
      selected.value = visit;
      _syncSupportItemEditors(visit);
      _loadParticipantNdis(visit);
    }
  }

  Future<void> updateVisitSupportItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) async {
    final visit = selected.value;
    if (visit == null || !canEditVisitSupportItem) return;
    if (supportItemCode == visit.supportItemCode &&
        supportItemName == visit.supportItemName) {
      return;
    }
    final previousCode = editingVisitSupportItemCode.value;
    final previousName = editingVisitSupportItemName.value;
    editingVisitSupportItemCode.value = supportItemCode;
    editingVisitSupportItemName.value = supportItemName;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.patchVisitSupportItem(
        visit.id,
        SupportItemPatch(
          supportItemCode: supportItemCode,
          supportItemName: supportItemName,
        ),
      );
      selected.value = updated;
      _syncVisitSupportItemEditor(updated);
    } on AppFailure catch (e) {
      editingVisitSupportItemCode.value = previousCode;
      editingVisitSupportItemName.value = previousName;
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateVisitPriceTier(String? priceTierOverride) async {
    final visit = selected.value;
    if (visit == null || !canEditVisitPriceTier) return;
    if (priceTierOverride == visit.priceTierOverride) return;

    final previous = editingPriceTierOverride.value;
    editingPriceTierOverride.value = priceTierOverride;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.patchVisitPriceTier(
        visit.id,
        VisitPriceTierPatch(priceTierOverride: priceTierOverride),
      );
      selected.value = updated;
      _syncPriceTierEditor(updated);
    } on AppFailure catch (e) {
      editingPriceTierOverride.value = previous;
      errorMessage.value = e.message;
      if (e.code == 'visit_already_exported') {
        priceTierEditBlocked.value = true;
      }
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateVisitTaskBillableMinutes({
    required VisitTaskOut task,
    required String rawMinutes,
  }) async {
    final visit = selected.value;
    if (visit == null || !canEditVisitTaskBilling) return;

    final code = taskSupportPickerCode(task) ?? task.supportItemCode;
    if (code == null || code.trim().isEmpty) return;

    final trimmed = rawMinutes.trim();
    if (trimmed.isEmpty) {
      errorMessage.value = 'Enter billable minutes (0–1440).';
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0 || parsed > maxTaskBillableMinutes) {
      errorMessage.value = 'Billable minutes must be a whole number from 0 to 1440.';
      return;
    }
    if (parsed == task.billableMinutes) return;

    final previous = editingTaskBillableMinutes[task.id];
    editingTaskBillableMinutes[task.id] = parsed;
    editingTaskBillableMinutes.refresh();
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updatedTask = await _repository.patchVisitTaskBilling(
        visitId: visit.id,
        taskId: task.id,
        body: VisitTaskBillingPatch(billableMinutes: parsed),
      );
      selected.value = _replaceTaskInVisit(visit, updatedTask);
      editingTaskBillableMinutes[task.id] = updatedTask.billableMinutes;
      editingTaskBillableMinutes.refresh();
    } on AppFailure catch (e) {
      editingTaskBillableMinutes[task.id] = previous;
      editingTaskBillableMinutes.refresh();
      errorMessage.value = e.message;
      if (e.code == 'visit_already_exported') {
        priceTierEditBlocked.value = true;
      }
    } finally {
      isSaving.value = false;
    }
  }

  int? taskBillableMinutesDisplay(VisitTaskOut task) =>
      editingTaskBillableMinutes[task.id] ?? task.billableMinutes;

  Future<void> updateVisitTaskSupportItem({
    required VisitTaskOut task,
    required String? supportItemCode,
    required String? supportItemName,
  }) async {
    final visit = selected.value;
    if (visit == null || !canEditVisitSupportItem) return;

    final clearing = supportItemCode == null && supportItemName == null;
    final code = clearing
        ? null
        : _pairedSupportItemCode(supportItemCode, supportItemName);

    // Incomplete pair (code without name) — ignore until catalogue row is picked.
    if (!clearing && code == null) return;

    // Code already on the task: still bind the catalogue name so the picker can
    // show the selected tile (VisitTaskOut only stores the code).
    if (!clearing && code == task.supportItemCode) {
      editingTaskSupportCodes[task.id] = code;
      editingTaskSupportNames[task.id] = supportItemName?.trim();
      editingTaskSupportCodes.refresh();
      editingTaskSupportNames.refresh();
      return;
    }

    final previousCode = editingTaskSupportCodes[task.id];
    final previousName = editingTaskSupportNames[task.id];
    editingTaskSupportCodes[task.id] = code;
    if (clearing) {
      editingTaskSupportNames.remove(task.id);
    } else {
      editingTaskSupportNames[task.id] = supportItemName?.trim();
    }
    editingTaskSupportCodes.refresh();
    editingTaskSupportNames.refresh();
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updatedTask = await _repository.patchVisitTaskSupportItem(
        visitId: visit.id,
        taskId: task.id,
        body: VisitTaskSupportItemPatch(supportItemCode: code),
      );
      selected.value = _replaceTaskInVisit(visit, updatedTask);
      editingTaskSupportCodes[task.id] = updatedTask.supportItemCode;
      editingTaskBillableMinutes[task.id] = updatedTask.billableMinutes;
      if (updatedTask.supportItemCode == null) {
        editingTaskSupportNames.remove(task.id);
        editingTaskBillableMinutes.remove(task.id);
      } else if (supportItemName != null && supportItemName.trim().isNotEmpty) {
        editingTaskSupportNames[task.id] = supportItemName.trim();
      }
      editingTaskSupportCodes.refresh();
      editingTaskSupportNames.refresh();
      editingTaskBillableMinutes.refresh();
    } on AppFailure catch (e) {
      editingTaskSupportCodes[task.id] = previousCode;
      if (previousName == null) {
        editingTaskSupportNames.remove(task.id);
      } else {
        editingTaskSupportNames[task.id] = previousName;
      }
      editingTaskSupportCodes.refresh();
      editingTaskSupportNames.refresh();
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  String? taskSupportPickerCode(VisitTaskOut task) =>
      editingTaskSupportCodes[task.id] ?? task.supportItemCode;

  String? taskSupportPickerName(VisitTaskOut task) =>
      editingTaskSupportNames[task.id];

  void _syncSupportItemEditors(VisitOut visit) {
    _syncVisitSupportItemEditor(visit);
    _syncTaskSupportEditors(visit);
    _syncPriceTierEditor(visit);
    _syncTaskBillableEditors(visit);
  }

  void _syncTaskBillableEditors(VisitOut visit) {
    editingTaskBillableMinutes.clear();
    for (final task in visit.tasks) {
      editingTaskBillableMinutes[task.id] = task.billableMinutes;
    }
    editingTaskBillableMinutes.refresh();
  }

  void _syncPriceTierEditor(VisitOut visit) {
    editingPriceTierOverride.value = visit.priceTierOverride;
  }

  void _syncVisitSupportItemEditor(VisitOut visit) {
    editingVisitSupportItemCode.value = visit.supportItemCode;
    editingVisitSupportItemName.value = visit.supportItemName;
  }

  void _syncTaskSupportEditors(VisitOut visit) {
    final preservedNames = Map<String, String?>.from(editingTaskSupportNames);
    editingTaskSupportCodes.clear();
    editingTaskSupportNames.clear();
    for (final task in visit.tasks) {
      editingTaskSupportCodes[task.id] = task.supportItemCode;
      final name = preservedNames[task.id];
      if (name != null && task.supportItemCode != null) {
        editingTaskSupportNames[task.id] = name;
      }
    }
    editingTaskSupportCodes.refresh();
    editingTaskSupportNames.refresh();
  }

  VisitOut _replaceTaskInVisit(VisitOut visit, VisitTaskOut task) {
    return visit.copyWith(
      tasks: [
        for (final existing in visit.tasks)
          if (existing.id == task.id) task else existing,
      ],
    );
  }

  String? _pairedSupportItemCode(String? code, String? name) {
    final c = code?.trim();
    final n = name?.trim();
    if (c == null || c.isEmpty || n == null || n.isEmpty) return null;
    return c;
  }

  Future<void> cancelSelected() async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.cancel(visit.id);
      await refreshSelected();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> rescheduleSelected({
    required DateTime start,
    required DateTime end,
  }) async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      selected.value = await _repository.reschedule(
        id: visit.id,
        scheduledStart: start,
        scheduledEnd: end,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
