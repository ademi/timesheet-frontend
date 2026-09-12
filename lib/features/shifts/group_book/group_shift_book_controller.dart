import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../core/time/tenant_civil_time.dart';
import '../../../shared/utils/name_sort.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../jobs/utils/required_slots_input.dart';
import '../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../data/models/shift_models.dart';
import '../data/repositories/shifts_repository.dart';
import '../utils/allocation_math.dart';
import '../utils/group_participant_draft.dart';
import '../utils/participant_window_math.dart';
import 'group_shift_book_args.dart';
import 'group_shift_windows_view.dart';

/// 3-step Group Shift booking wizard (People · When · Review).
class GroupShiftBookController extends GetxController {
  GroupShiftBookController({
    required ClientsRepository clientsRepository,
    required JobsRepository jobsRepository,
    required ShiftsRepository shiftsRepository,
    required SessionService session,
    PayrollRepository? payroll,
    GroupShiftBookArgs? args,
    void Function(String route, dynamic arguments)? onNavigate,
    Future<bool> Function(int nextN)? confirmLargeGroup,
    Future<List<ParticipantWindowDraft>?> Function(
      GroupShiftWindowsArgs args,
    )?
    openWindowsEditor,
  }) : _clients = clientsRepository,
       _jobs = jobsRepository,
       _shifts = shiftsRepository,
       _session = session,
       _payroll = payroll,
       _args = args,
       _onNavigate = onNavigate,
       _confirmLargeGroup = confirmLargeGroup,
       _openWindowsEditor = openWindowsEditor;

  final ClientsRepository _clients;
  final JobsRepository _jobs;
  final ShiftsRepository _shifts;
  final SessionService _session;
  final PayrollRepository? _payroll;
  final GroupShiftBookArgs? _args;
  final void Function(String route, dynamic arguments)? _onNavigate;
  final Future<bool> Function(int nextN)? _confirmLargeGroup;
  final Future<List<ParticipantWindowDraft>?> Function(
    GroupShiftWindowsArgs args,
  )?
  _openWindowsEditor;

  static const int peopleStep = 0;
  static const int whenStep = 1;
  static const int reviewStep = 2;
  static const int maxStep = reviewStep;
  static const stepLabels = ['People', 'When', 'Review'];

  final step = 0.obs;
  final host = Rxn<ClientOut>();
  final includeHost = false.obs;
  final draft = GroupParticipantDraftSet(equalSplit: true).obs;
  final clients = <ClientOut>[].obs;

  final scheduledStart =
      DateTime.now().add(const Duration(hours: 1)).obs;
  final scheduledEnd =
      DateTime.now().add(const Duration(hours: 3)).obs;
  final requiredSlots = 1.obs;
  final workerCount = 1.obs;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final clientSearch = ''.obs;

  bool get canManage =>
      _session.hasPermission(AppPermissions.shiftsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  bool get slotsMismatch => workerCount.value != requiredSlots.value;

  bool get isTimeBased => draft.value.isTimeBased;

  String get remainingLabel =>
      remainingCapacityLabel(draft.value.participants.map((p) => p.allocationValue));

  List<ClientOut> get filteredClients {
    final q = clientSearch.value.trim().toLowerCase();
    final list = sortedByName(clients, (c) => c.fullName);
    if (q.isEmpty) return list;
    return [for (final c in list) if (c.fullName.toLowerCase().contains(q)) c];
  }

  List<ClientOut> get pickerCandidates {
    final taken = {
      for (final p in draft.value.participants) p.participantId,
    };
    return [
      for (final c in filteredClients)
        if (!taken.contains(c.id)) c,
    ];
  }

  @override
  void onInit() {
    super.onInit();
    ever(scheduledStart, (DateTime start) {
      if (!scheduledEnd.value.isAfter(start)) {
        scheduledEnd.value = start.add(const Duration(hours: 1));
      }
      _alignDraftWindowsToSchedule();
    });
    ever(scheduledEnd, (_) => _alignDraftWindowsToSchedule());
    _bootstrap();
  }

  /// Keeps time-based windows inside the current When-step bounds.
  void _alignDraftWindowsToSchedule() {
    if (!isTimeBased) return;
    final start = scheduledStart.value;
    final end = scheduledEnd.value;
    if (!end.isAfter(start)) return;
    draft.value = draft.value.copyWith(
      participants: [
        for (final p in draft.value.participants)
          p.copyWith(
            timeWindows: alignWindowsToShiftBounds(
              p.timeWindows,
              shiftStart: start,
              shiftEnd: end,
            ),
          ),
      ],
    );
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      clients.assignAll(await _clients.listClients());
      _applyPrefillArgs();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void _applyPrefillArgs() {
    final args = _args;
    if (args == null) return;

    ClientOut? prefill = args.participant;
    if (prefill == null && args.participantId != null) {
      for (final c in clients) {
        if (c.id == args.participantId) {
          prefill = c;
          break;
        }
      }
    }
    if (prefill == null &&
        args.participantId != null &&
        (args.participantName?.isNotEmpty ?? false)) {
      // Minimal stub so filter prefill still works if listClients missed them.
      prefill = ClientOut(
        id: args.participantId!,
        tenantId: '',
        fullName: args.participantName!,
        status: 'active',
        metadata: const {},
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }
    if (prefill != null) {
      draft.value = draft.value.add(
        GroupParticipantDraft(
          participantId: prefill.id,
          displayName: prefill.fullName,
          allocationValue: 0,
        ),
      );
    }
  }

  void selectHost(ClientOut? client) {
    host.value = client;
    if (includeHost.value) {
      _syncHostParticipant();
    }
  }

  void setIncludeHost(bool value) {
    includeHost.value = value;
    _syncHostParticipant();
  }

  void _syncHostParticipant() {
    var next = draft.value;
    final existingHostRows = [
      for (final p in next.participants)
        if (p.isHostIncluded) p.participantId,
    ];
    for (final id in existingHostRows) {
      next = next.remove(id);
    }
    final h = host.value;
    if (includeHost.value && h != null && !next.containsParticipant(h.id)) {
      next = next.add(
        GroupParticipantDraft(
          participantId: h.id,
          displayName: h.fullName,
          allocationValue: 0,
          isHostIncluded: true,
          timeWindows:
              next.isTimeBased
                  ? defaultFullShiftWindows(
                    scheduledStart.value,
                    scheduledEnd.value,
                  )
                  : const [],
        ),
      );
    }
    draft.value = next;
  }

  void setAllocationStrategy(String strategy) {
    draft.value = draft.value.withAllocationStrategy(
      strategy,
      shiftStart: scheduledStart.value,
      shiftEnd: scheduledEnd.value,
    );
    errorMessage.value = null;
  }

  void setEqualSplit(bool enabled) {
    draft.value = draft.value.withEqualSplit(enabled);
    errorMessage.value = null;
  }

  void setAllocation(String participantId, double value) {
    draft.value = draft.value.setAllocation(participantId, value);
  }

  void removeParticipant(String participantId) {
    final row = draft.value.participants
        .where((p) => p.participantId == participantId)
        .firstOrNull;
    draft.value = draft.value.remove(participantId);
    if (row?.isHostIncluded == true) {
      includeHost.value = false;
    }
  }

  Future<void> editWindows(GroupParticipantDraft row) async {
    final args = GroupShiftWindowsArgs(
      displayName: row.displayName,
      windows: row.timeWindows,
      shiftStart: scheduledStart.value,
      shiftEnd: scheduledEnd.value,
    );
    List<ParticipantWindowDraft>? result;
    if (_openWindowsEditor != null) {
      result = await _openWindowsEditor(args);
    } else if (!Get.testMode) {
      result = await Get.to<List<ParticipantWindowDraft>>(
        () => GroupShiftWindowsView(args: args),
      );
    }
    if (result != null) {
      draft.value = draft.value.setTimeWindows(row.participantId, result);
      errorMessage.value = null;
    }
  }

  /// Returns false when add was cancelled (hard cap or large-group dialog).
  Future<bool> addParticipant(ClientOut client) async {
    if (draft.value.containsParticipant(client.id)) return false;
    final nextN = draft.value.length + 1;
    if (atHardCap(draft.value.length)) {
      errorMessage.value = 'Groups are limited to 32 participants';
      return false;
    }
    if (needsLargeGroupConfirm(nextN)) {
      final ok = await _askLargeGroupConfirm(nextN);
      if (!ok) return false;
    }
    final isHostRow = includeHost.value && host.value?.id == client.id;
    final windows =
        isTimeBased
            ? defaultFullShiftWindows(
              scheduledStart.value,
              scheduledEnd.value,
            )
            : const <ParticipantWindowDraft>[];
    draft.value = draft.value.add(
      GroupParticipantDraft(
        participantId: client.id,
        displayName: client.fullName,
        allocationValue: 0,
        isHostIncluded: isHostRow,
        timeWindows: windows,
      ),
    );
    if (isHostRow) includeHost.value = true;
    errorMessage.value = null;
    return true;
  }

  Future<bool> _askLargeGroupConfirm(int nextN) async {
    if (_confirmLargeGroup != null) {
      return _confirmLargeGroup(nextN);
    }
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

  void setRequiredSlots(String raw) {
    requiredSlots.value = parseRequiredSlots(raw);
  }

  void setWorkerCount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final n = int.tryParse(digits) ?? 1;
    workerCount.value = n < 1 ? 1 : n;
  }

  bool canGoNext() {
    errorMessage.value = null;
    switch (step.value) {
      case peopleStep:
        return _validatePeople(showError: true);
      case whenStep:
        return _validateWhen(showError: true);
      default:
        return true;
    }
  }

  bool _validatePeople({required bool showError}) {
    void fail(String msg) {
      if (showError) errorMessage.value = msg;
    }

    if (host.value == null) {
      fail('Select a host (venue / standing job).');
      return false;
    }
    if (draft.value.participants.isEmpty) {
      fail('Add at least one participant');
      return false;
    }
    if (draft.value.participants.length > 32) {
      fail('Groups are limited to 32 participants');
      return false;
    }
    if (!isTimeBased &&
        !draft.value.equalSplit &&
        !sumsTo100(draft.value.participants.map((p) => p.allocationValue))) {
      fail(remainingLabel);
      return false;
    }
    final validation = draft.value.validate(
      shiftStart: scheduledStart.value,
      shiftEnd: scheduledEnd.value,
    );
    if (validation != null) {
      fail(validation);
      return false;
    }
    return true;
  }

  bool _validateWhen({required bool showError}) {
    if (!scheduledEnd.value.isAfter(scheduledStart.value)) {
      if (showError) errorMessage.value = 'End must be after start.';
      return false;
    }
    if (workerCount.value < 1) {
      if (showError) errorMessage.value = 'Workers planned must be at least 1.';
      return false;
    }
    if (isTimeBased) {
      final validation = draft.value.validate(
        shiftStart: scheduledStart.value,
        shiftEnd: scheduledEnd.value,
      );
      if (validation != null) {
        if (showError) errorMessage.value = validation;
        return false;
      }
    }
    return true;
  }

  void nextStep() {
    if (!canGoNext()) return;
    if (step.value < maxStep) step.value++;
  }

  void previousStep() {
    errorMessage.value = null;
    if (step.value > 0) step.value--;
  }

  Future<void> createDraft() async {
    if (isSaving.value || !canManage) return;
    errorMessage.value = null;
    if (!_validatePeople(showError: true)) {
      step.value = peopleStep;
      return;
    }
    if (!_validateWhen(showError: true)) {
      step.value = whenStep;
      return;
    }

    isSaving.value = true;
    try {
      final hostClient = host.value!;
      final support = await _jobs.ensureOngoingSupport(hostClient.id);
      final tz = await _resolveTenantTimezone();
      final startUtc = tenantCivilInstantUtc(scheduledStart.value, tz);
      final endUtc = tenantCivilInstantUtc(scheduledEnd.value, tz);
      final timeBased = isTimeBased;
      final equal = !timeBased && draft.value.equalSplit;
      final strategy =
          timeBased
              ? GroupAllocationStrategy.timeBased
              : GroupAllocationStrategy.percentage;
      final created = await _shifts.createShift(
        ShiftCreateRequest(
          jobId: support.id,
          scheduledStart: startUtc,
          scheduledEnd: endUtc,
          requiredSlots: requiredSlots.value,
          workerCount: workerCount.value,
          status: 'draft',
          equalSplit: equal,
          participants: [
            for (final p in draft.value.participants)
              ShiftParticipantCreateItem(
                participantId: p.participantId,
                allocationStrategy: strategy,
                allocationValue:
                    timeBased ? 0 : (equal ? null : p.allocationValue),
                reason: 'group_shift_book',
                timeWindows:
                    timeBased
                        ? [
                          for (final w in p.timeWindows)
                            ShiftParticipantTimeWindowInput(
                              // Windows were edited in local civil time; map
                              // onto the same UTC instants as the shift.
                              participantStartTime: tenantCivilInstantUtc(
                                w.start,
                                tz,
                              ),
                              participantEndTime: tenantCivilInstantUtc(
                                w.end,
                                tz,
                              ),
                            ),
                        ]
                        : null,
              ),
          ],
        ),
      );
      if (!Get.testMode) {
        AppToast.success('Draft group shift created', created.jobTitle);
      }
      _navigate(AppRoutes.staffShiftDetail, created);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) {
        AppToast.error('Could not create', e.message);
      }
    } catch (e) {
      errorMessage.value = e.toString();
      if (!Get.testMode) {
        AppToast.error('Could not create', e.toString());
      }
    } finally {
      isSaving.value = false;
    }
  }

  void _navigate(String route, dynamic arguments) {
    if (_onNavigate != null) {
      _onNavigate(route, arguments);
      return;
    }
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
    final id = _session.tenantId.value;
    if (id == null || id.isEmpty || _payroll == null) return null;
    try {
      final t = await _payroll.getTenant(id);
      return t.timezone?.trim();
    } catch (_) {
      return null;
    }
  }
}
