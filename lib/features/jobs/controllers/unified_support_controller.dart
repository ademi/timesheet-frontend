import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../core/time/tenant_civil_time.dart';
import '../../../shared/utils/name_sort.dart';
import '../../billing/data/models/billing_models.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../clients/controllers/clients_controller.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/models/client_profile_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../clients/utils/client_quick_facts.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../../visits/data/models/roster_overlay_models.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../../visits/utils/assign_availability.dart';
import '../../visits/utils/assign_schedule_window.dart';
import '../data/models/job_models.dart';
import '../data/repositories/jobs_repository.dart';
import '../utils/job_copy.dart';
import '../utils/partial_assign_preview.dart' as partial_preview;
import '../utils/recurrence_rrule_builder.dart';
import '../utils/required_slots_input.dart';
import '../utils/schedule_conflict.dart';
import '../utils/schedule_hours_warn.dart';
import '../utils/time_window_utils.dart';
import '../utils/unified_support_args.dart';
import '../utils/task_title_presets.dart';
import 'recurrence_workers_selection.dart';

String formatSupportTimeOfDay(TimeOfDay time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

class UnifiedSupportController extends GetxController
    with RecurrenceWorkersSelection {
  UnifiedSupportController({
    required JobsRepository jobsRepository,
    required ClientsRepository clientsRepository,
    required EngagementsRepository engagementsRepository,
    required ShiftsRepository shiftsRepository,
    required VisitsRepository visitsRepository,
    required SessionService session,
    PayrollRepository? payroll,
    UnifiedSupportArgs? args,
    void Function(String route, dynamic arguments)? onNavigate,
  }) : _jobs = jobsRepository,
       _clients = clientsRepository,
       _engagements = engagementsRepository,
       _shifts = shiftsRepository,
       _visits = visitsRepository,
       _session = session,
       _payroll = payroll,
       _args = args,
       _onNavigate = onNavigate;

  final JobsRepository _jobs;
  final ClientsRepository _clients;
  final EngagementsRepository _engagements;
  final ShiftsRepository _shifts;
  final VisitsRepository _visits;
  final SessionService _session;
  final PayrollRepository? _payroll;
  final UnifiedSupportArgs? _args;
  final void Function(String route, dynamic arguments)? _onNavigate;

  static const int typeStep = 0;
  static const int locationStep = 1;
  static const int scheduleStep = 2;
  static const int detailsStep = 3;
  static const int assignStep = 4;
  static const int maxStep = assignStep;

  final step = 0.obs;
  final mode = Rxn<UnifiedSupportMode>();
  final client = Rxn<ClientOut>();

  final titleCtrl = TextEditingController();
  final taskTemplate = <TaskTemplateItem>[].obs;
  final instructionsCtrl = TextEditingController();
  final startTime = const TimeOfDay(hour: 9, minute: 0).obs;
  final endTime = const TimeOfDay(hour: 12, minute: 0).obs;
  final oneSessionStart = DateTime.now().add(const Duration(hours: 1)).obs;
  final oneSessionEnd =
      DateTime.now().add(const Duration(hours: 3)).obs;
  final publishImmediately = true.obs;

  final selectedSiteId = RxnString();
  final frequency = RecurrenceFrequency.weekly.obs;
  final weekdays = <int>{DateTime.monday}.obs;
  final startDate = DateTime.now().obs;
  final endDate = Rx<DateTime>(defaultRecurrenceEndDate(DateTime.now()));
  final requiredSlots = 1.obs;
  final supportItemCode = RxnString();
  final supportItemName = RxnString();
  final selectedFormTemplateIds = <String>{}.obs;

  final clients = <ClientOut>[].obs;
  final sites = <ClientSiteOut>[].obs;
  final formTemplates = <FormTemplateOut>[].obs;
  final engagements = <EngagementOut>[].obs;
  final profileFacts = <ClientProfileFactOut>[].obs;
  final clientTypeName = RxnString();
  final clientTypeCode = RxnString();

  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final scheduleWarnTimezone = RxnString();
  final assignOverlay = Rxn<RosterOverlayOut>();
  final assignShifts = <ShiftOut>[].obs;
  final assignVisits = <VisitOut>[].obs;
  final assignOverlayWarning = RxnString();
  final isAssignAvailabilityLoading = false.obs;
  final conflictVisits = <VisitOut>[].obs;
  final conflictShifts = <ShiftOut>[].obs;
  final isConflictsLoading = false.obs;

  bool engagementsLoaded = false;
  bool assignAvailabilityLoaded = false;
  bool clientConflictsLoaded = false;
  String? _assignAvailabilityKey;
  String? _clientConflictsKey;
  String? _standingJobId;
  String? _standingJobClientId;
  bool _supportItemUserChanged = false;
  bool _supportItemPrefilledFromStanding = false;
  Future<void>? _engagementsLoadFuture;
  Future<void>? _assignAvailabilityLoadFuture;
  Future<void>? _clientConflictsLoadFuture;

  bool get canManage => _session.hasPermission(AppPermissions.jobsManage);

  bool get isOngoing => mode.value == UnifiedSupportMode.ongoing;
  bool get isOneSession => mode.value == UnifiedSupportMode.oneSession;

  bool get requiresWeekdays =>
      frequency.value == RecurrenceFrequency.weekly ||
      frequency.value == RecurrenceFrequency.fortnightly;

  bool get blocksWithoutSites => sites.isEmpty;

  bool get needsClientPicker => client.value == null;

  String? get clientNdisNumber => ndisFromFacts(profileFacts);

  bool get showNdisCapturePrompt {
    if (client.value == null) return false;
    if (clientNdisNumber != null && clientNdisNumber!.isNotEmpty) return false;
    return isPatientClientType(
      typeName: clientTypeName.value,
      typeCode: clientTypeCode.value,
    );
  }

  List<String> get carePlanTaskTitles =>
      [for (final task in taskTemplate) task.title];

  bool get supportItemPrefilledFromStanding => _supportItemPrefilledFromStanding;

  List<EngagementOut> get assignableEngagements => sortedByName(
        engagements.where((e) => e.isActive || e.isApproved || e.isPendingDocs),
        (e) => e.displayName,
      );

  @override
  void onInit() {
    super.onInit();
    ever(startDate, (DateTime start) {
      if (endDate.value.isBefore(start)) {
        endDate.value = defaultRecurrenceEndDate(start);
      }
    });
    ever(requiredSlots, (_) => syncAssignSlots());
    syncAssignSlots();
    ever(oneSessionStart, (DateTime start) {
      if (!oneSessionEnd.value.isAfter(start)) {
        oneSessionEnd.value = start.add(const Duration(hours: 1));
      }
      _invalidateAssignAvailability();
    });
    ever(oneSessionEnd, (_) => _invalidateAssignAvailability());
    ever(startDate, (_) => _invalidateAssignAvailability());
    ever(startTime, (_) => _invalidateAssignAvailability());
    ever(endTime, (_) => _invalidateAssignAvailability());
    ever(frequency, (_) => _invalidateAssignAvailability());
    ever(weekdays, (_) => _invalidateAssignAvailability());
    _bootstrap();
    _cacheTenantTimezone();
  }

  Future<void> _cacheTenantTimezone() async {
    scheduleWarnTimezone.value = await _resolveTenantTimezone();
  }

  String? get _tenantTimezoneForScheduleWarn {
    final sessionTz = _session.tenantTimezone.value?.trim();
    if (sessionTz != null && sessionTz.isNotEmpty) return sessionTz;
    return scheduleWarnTimezone.value;
  }

  bool get showScheduleHoursWarn {
    final tz = _tenantTimezoneForScheduleWarn;
    if (isOneSession) {
      return shouldWarnAtypicalHours(
        start: oneSessionStart.value,
        end: oneSessionEnd.value,
        tenantTimezone: tz,
      );
    }
    return shouldWarnAtypicalOngoingSchedule(
      frequency: frequency.value,
      weekdays: weekdays.toSet(),
      startTime: startTime.value,
      endTime: endTime.value,
      startDate: startDate.value,
      tenantTimezone: tz,
    );
  }

  /// Loads client, sites, and templates for the composer.
  Future<void> load() => _bootstrap();

  @override
  void onClose() {
    titleCtrl.dispose();
    instructionsCtrl.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final args = _args ?? _parseRouteArgs();
      mode.value = args?.initialMode;

      ClientOut? resolved = args?.client;
      final id = args?.clientId ?? args?.client?.id;
      if (resolved == null && id != null && id.isNotEmpty) {
        try {
          resolved = await _clients.getClient(id);
        } on AppFailure catch (e) {
          errorMessage.value = e.message;
        }
      }
      if (resolved != null) {
        await selectClient(resolved);
      } else {
        try {
          clients.assignAll(await _clients.listClients());
        } on AppFailure catch (e) {
          errorMessage.value = e.message;
        }
      }

      try {
        formTemplates.assignAll(
          await _jobs.listFormTemplates(tenantLevel: true),
        );
      } catch (_) {
        formTemplates.clear();
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> ensureEngagementsLoaded() async {
    if (engagementsLoaded) return;
    if (_engagementsLoadFuture != null) {
      await _engagementsLoadFuture;
      return;
    }
    _engagementsLoadFuture = _loadEngagements();
    try {
      await _engagementsLoadFuture;
    } finally {
      _engagementsLoadFuture = null;
    }
  }

  Future<void> _loadEngagements() async {
    try {
      engagements.assignAll(await _engagements.listTenantEngagements());
    } catch (_) {
      engagements.clear();
    }
    engagementsLoaded = true;
  }

  /// Loads roster overlay + shifts for the proposed schedule window (assign step).
  Future<void> ensureAssignAvailabilityLoaded() async {
    if (step.value != assignStep) return;
    final window = computeAssignScheduleWindow(
      isOneSession: isOneSession,
      oneSessionStart: oneSessionStart.value,
      oneSessionEnd: oneSessionEnd.value,
      startDate: startDate.value,
      frequency: frequency.value,
      weekdays: weekdays.toSet(),
      startTime: startTime.value,
      endTime: endTime.value,
    );
    final tz = _tenantTimezoneForScheduleWarn ?? await _resolveTenantTimezone();
    final query = assignAvailabilityQueryWindow(
      window: window,
      tenantTimezone: tz,
    );
    var fetchFrom = query.from;
    var fetchTo = query.to;
    if (isOngoing) {
      final horizon = tenantHorizonWindowUtc(DateTime.now().toUtc(), tz);
      fetchFrom = horizon.from;
      fetchTo = horizon.to;
    }
    final key =
        '${query.from.toIso8601String()}|${query.to.toIso8601String()}|${query.shiftStart.toIso8601String()}|${query.shiftEnd.toIso8601String()}|${fetchFrom.toIso8601String()}|${fetchTo.toIso8601String()}';
    if (assignAvailabilityLoaded && _assignAvailabilityKey == key) return;
    if (_assignAvailabilityLoadFuture != null) {
      await _assignAvailabilityLoadFuture;
      if (assignAvailabilityLoaded && _assignAvailabilityKey == key) return;
    }

    _assignAvailabilityLoadFuture = _loadAssignAvailability(
      query,
      key,
      fetchFrom: fetchFrom,
      fetchTo: fetchTo,
    );
    try {
      await _assignAvailabilityLoadFuture;
    } finally {
      _assignAvailabilityLoadFuture = null;
    }
  }

  Future<void> _loadAssignAvailability(
    ({
      DateTime from,
      DateTime to,
      DateTime shiftStart,
      DateTime shiftEnd,
      DateTime day,
      DateTime startCivil,
      DateTime endCivil,
    }) query,
    String key, {
    required DateTime fetchFrom,
    required DateTime fetchTo,
  }) async {
    isAssignAvailabilityLoading.value = true;
    assignOverlayWarning.value = null;
    try {
      final shiftsFuture = () async {
        try {
          return await _shifts.listShifts(from: fetchFrom, to: fetchTo);
        } catch (_) {
          return const <ShiftOut>[];
        }
      }();
      final visitsFuture = () async {
        try {
          return await _visits.listVisits(
            from: fetchFrom,
            to: fetchTo,
            includeNested: false,
          );
        } catch (_) {
          return const <VisitOut>[];
        }
      }();
      final overlayFuture = () async {
        try {
          return await _visits.fetchRosterOverlay(
            from: fetchFrom,
            to: fetchTo,
          );
        } catch (_) {
          // Only this failure means leave / preferred hours are unknown.
          assignOverlayWarning.value =
              'Could not load leave and preferred hours';
          return null;
        }
      }();
      assignShifts.assignAll(await shiftsFuture);
      assignVisits.assignAll(await visitsFuture);
      assignOverlay.value =
          await overlayFuture ?? const RosterOverlayOut(contractors: []);
      _assignAvailabilityWindow = query;
      _assignAvailabilityKey = key;
      assignAvailabilityLoaded = true;
    } catch (_) {
      assignShifts.clear();
      assignVisits.clear();
      assignOverlay.value = const RosterOverlayOut(contractors: []);
      // Unexpected failure after individual fetches — do not claim leave
      // specifically failed unless the overlay path already set a warning.
      assignOverlayWarning.value ??=
          'Could not load worker availability';
      _assignAvailabilityWindow = query;
      _assignAvailabilityKey = key;
      assignAvailabilityLoaded = true;
    } finally {
      isAssignAvailabilityLoading.value = false;
    }
  }

  /// Loads lite client visits + standing-job shifts for the schedule strip (D19).
  Future<void> ensureClientConflictsLoaded() async {
    if (step.value != scheduleStep && step.value != assignStep) return;
    if (client.value == null) return;
    if (!_validateSchedule(showError: false)) return;
    final window = computeAssignScheduleWindow(
      isOneSession: isOneSession,
      oneSessionStart: oneSessionStart.value,
      oneSessionEnd: oneSessionEnd.value,
      startDate: startDate.value,
      frequency: frequency.value,
      weekdays: weekdays.toSet(),
      startTime: startTime.value,
      endTime: endTime.value,
    );
    final tz = _tenantTimezoneForScheduleWarn ?? await _resolveTenantTimezone();
    final query = assignAvailabilityQueryWindow(
      window: window,
      tenantTimezone: tz,
    );
    final clientId = client.value!.id;
    final key =
        '$clientId|${query.from.toIso8601String()}|${query.to.toIso8601String()}|${query.shiftStart.toIso8601String()}|${query.shiftEnd.toIso8601String()}';
    if (clientConflictsLoaded && _clientConflictsKey == key) return;
    if (_clientConflictsLoadFuture != null) {
      await _clientConflictsLoadFuture;
      if (clientConflictsLoaded && _clientConflictsKey == key) return;
    }

    _clientConflictsLoadFuture = _loadClientConflicts(query, key, clientId);
    try {
      await _clientConflictsLoadFuture;
    } finally {
      _clientConflictsLoadFuture = null;
    }
  }

  Future<void> _loadClientConflicts(
    ({
      DateTime from,
      DateTime to,
      DateTime shiftStart,
      DateTime shiftEnd,
      DateTime day,
      DateTime startCivil,
      DateTime endCivil,
    }) query,
    String key,
    String clientId,
  ) async {
    isConflictsLoading.value = true;
    try {
      final standingJobId = await _resolveStandingJobId(clientId);
      final visitsFuture = () async {
        try {
          return await _visits.listVisits(
            clientId: clientId,
            from: query.from,
            to: query.to,
            includeNested: false,
          );
        } catch (_) {
          return const <VisitOut>[];
        }
      }();
      final shiftsFuture = () async {
        try {
          return await _shifts.listShifts(
            from: query.from,
            to: query.to,
            jobId: standingJobId,
          );
        } catch (_) {
          return const <ShiftOut>[];
        }
      }();
      conflictVisits.assignAll(await visitsFuture);
      var shifts = await shiftsFuture;
      if (standingJobId == null) {
        shifts = shifts.where((s) => s.clientId == clientId).toList();
      }
      conflictShifts.assignAll(shifts);
      _conflictsWindow = query;
      _clientConflictsKey = key;
      clientConflictsLoaded = true;
    } catch (_) {
      conflictVisits.clear();
      conflictShifts.clear();
      _conflictsWindow = query;
      _clientConflictsKey = key;
      clientConflictsLoaded = true;
    } finally {
      isConflictsLoading.value = false;
    }
  }

  Future<String?> _resolveStandingJobId(String clientId) async {
    if (_standingJobClientId == clientId) {
      return _standingJobId;
    }
    try {
      final job = await _jobs.getOngoingSupport(clientId);
      _standingJobId = job.id;
      _standingJobClientId = clientId;
      return job.id;
    } catch (_) {
      _standingJobId = null;
      _standingJobClientId = clientId;
      return null;
    }
  }

  ({
    DateTime from,
    DateTime to,
    DateTime shiftStart,
    DateTime shiftEnd,
    DateTime day,
    DateTime startCivil,
    DateTime endCivil,
  })?
  _assignAvailabilityWindow;

  ({
    DateTime from,
    DateTime to,
    DateTime shiftStart,
    DateTime shiftEnd,
    DateTime day,
    DateTime startCivil,
    DateTime endCivil,
  })?
  _conflictsWindow;

  String availabilityStatusForContractor(String contractorId) {
    final query = _assignAvailabilityWindow;
    if (query == null) return 'Free';
    return assignAvailabilityLabel(
      contractorId: contractorId,
      day: query.day,
      shiftStart: query.shiftStart,
      shiftEnd: query.shiftEnd,
      windowStart: query.startCivil,
      windowEnd: query.endCivil,
      overlay: assignOverlay.value ?? const RosterOverlayOut(contractors: []),
      shifts: assignShifts.toList(growable: false),
      visits: assignVisits.toList(growable: false),
    );
  }

  /// UI copy. Ongoing: "$status on first date". One-session: base status.
  String availabilityDisplayLabelForContractor(String contractorId) {
    final status = availabilityStatusForContractor(contractorId);
    if (!isOngoing) return status;
    return '$status on first date';
  }

  /// Base availability token; prefer [availabilityDisplayLabelForContractor] in UI.
  String availabilityLabelForContractor(String contractorId) =>
      availabilityStatusForContractor(contractorId);

  /// Filled assign slots where the worker already has an overlapping visit/shift.
  List<({String contractorId, String displayName})> get busyAssignedWorkers {
    final results = <({String contractorId, String displayName})>[];
    final seen = <String>{};
    for (final id in filledContractorIds) {
      if (seen.add(id) && availabilityStatusForContractor(id) == 'Busy') {
        final name = assignableEngagements
            .where((e) => e.contractorId == id)
            .map((e) => e.displayName)
            .firstOrNull;
        results.add((contractorId: id, displayName: name ?? id));
      }
    }
    return results;
  }

  void syncTaskTemplateFromInstructions() {
    final titles = parseTaskTitles(instructionsCtrl.text);
    taskTemplate.assignAll([
      for (var i = 0; i < titles.length; i++)
        TaskTemplateItem(title: titles[i], sortOrder: i),
    ]);
  }

  void loadInstructionsFromTaskTemplate() {
    if (taskTemplate.isEmpty) {
      instructionsCtrl.clear();
      return;
    }
    instructionsCtrl.text = taskTemplate.map((t) => t.title).join('\n');
  }

  /// Dates in the fill horizon where a selected worker would be skipped (overlap).
  Future<List<partial_preview.PartialAssignWorkerPreview>>
      buildPartialAssignPreview() async {
    if (filledContractorIds.isEmpty || !assignAvailabilityLoaded) {
      return const [];
    }
    final tz = await _resolveTenantTimezone();
    final horizon = tenantHorizonWindowUtc(DateTime.now().toUtc(), tz);
    final occurrences = partial_preview.expandUnifiedSupportOccurrences(
      isOneSession: isOneSession,
      oneSessionStart: oneSessionStart.value,
      oneSessionEnd: oneSessionEnd.value,
      startDate: startDate.value,
      endDate: endDate.value,
      frequency: frequency.value,
      weekdays: weekdays.toSet(),
      startTime: startTime.value,
      endTime: endTime.value,
      horizonFromUtc: horizon.from,
      horizonToUtc: horizon.to,
      tenantTimezone: tz,
    );
    return partial_preview.buildPartialAssignPreview(
      contractorIds: filledContractorIds,
      displayNameFor: (id) {
        for (final e in assignableEngagements) {
          if (e.contractorId == id) return e.displayName;
        }
        return null;
      },
      occurrences: occurrences,
      overlay: assignOverlay.value ?? const RosterOverlayOut(contractors: []),
      shifts: assignShifts.toList(growable: false),
      visits: assignVisits.toList(growable: false),
    );
  }

  List<ClientConflict> get clientConflicts {
    final query = _conflictsWindow ?? _assignAvailabilityWindow;
    if (query == null) return const [];
    return buildClientConflicts(
      windowStart: query.shiftStart,
      windowEnd: query.shiftEnd,
      visits: conflictVisits.toList(growable: false),
      shifts: conflictShifts.toList(growable: false),
    );
  }

  void _invalidateAssignAvailability() {
    assignAvailabilityLoaded = false;
    _assignAvailabilityKey = null;
    _assignAvailabilityWindow = null;
    assignOverlay.value = null;
    assignShifts.clear();
    assignVisits.clear();
    assignOverlayWarning.value = null;
    _invalidateClientConflicts();
    if (step.value == scheduleStep || step.value == assignStep) {
      ensureClientConflictsLoaded();
    }
    if (step.value == assignStep) {
      ensureAssignAvailabilityLoaded();
    }
  }

  void _invalidateClientConflicts() {
    clientConflictsLoaded = false;
    _clientConflictsKey = null;
    _conflictsWindow = null;
    conflictVisits.clear();
    conflictShifts.clear();
  }

  UnifiedSupportArgs? _parseRouteArgs() {
    final raw = Get.arguments;
    if (raw is UnifiedSupportArgs) return raw;
    if (raw is ClientOut) {
      return UnifiedSupportArgs.forClient(
        raw,
        mode: UnifiedSupportMode.ongoing,
      );
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final modeRaw = map['mode']?.toString();
      UnifiedSupportMode? m;
      if (modeRaw == 'one' || modeRaw == 'oneSession') {
        m = UnifiedSupportMode.oneSession;
      } else if (modeRaw == 'ongoing') {
        m = UnifiedSupportMode.ongoing;
      }
      final clientArg = map['client'];
      return UnifiedSupportArgs(
        client: clientArg is ClientOut ? clientArg : null,
        clientId: map['client_id']?.toString() ?? map['clientId']?.toString(),
        initialMode: m,
      );
    }
    return null;
  }

  Future<void> selectClient(ClientOut value) async {
    final previousClientId = client.value?.id;
    final clientChanged = previousClientId != value.id;
    if (_standingJobClientId != value.id) {
      _standingJobId = null;
      _standingJobClientId = null;
      _invalidateClientConflicts();
    }
    if (clientChanged && previousClientId != null) {
      _supportItemUserChanged = false;
      _supportItemPrefilledFromStanding = false;
      supportItemCode.value = null;
      supportItemName.value = null;
    }
    client.value = value;
    if (titleCtrl.text.trim().isEmpty) {
      titleCtrl.text = defaultOngoingTitle(value.fullName);
    }
    await Future.wait([reloadSites(), _loadClientProfile(value.id)]);
    await _prefillSupportItemFromStandingJob(value.id);
  }

  Future<void> _prefillSupportItemFromStandingJob(String clientId) async {
    if (_supportItemUserChanged) return;
    try {
      final job = await _jobs.getOngoingSupport(clientId);
      _standingJobId = job.id;
      _standingJobClientId = clientId;
      final code = job.supportItemCode?.trim();
      final name = job.supportItemName?.trim();
      if (code != null &&
          code.isNotEmpty &&
          name != null &&
          name.isNotEmpty) {
        supportItemCode.value = code;
        supportItemName.value = name;
        _supportItemPrefilledFromStanding = true;
      }
    } catch (_) {
      // Soft-fail when the client has no standing support job yet.
    }
  }

  Future<void> _loadClientProfile(String clientId) async {
    try {
      final bundle = await _clients.getClientProfile(clientId);
      profileFacts.assignAll(bundle.facts);
      clientTypeName.value = bundle.clientType?.name;
      clientTypeCode.value = bundle.clientType?.code;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      profileFacts.clear();
      clientTypeName.value = null;
      clientTypeCode.value = null;
    } catch (_) {
      profileFacts.clear();
    }
  }

  Future<void> selectClientById(String? id) async {
    if (id == null) return;
    final match = clients.where((c) => c.id == id).firstOrNull;
    if (match != null) {
      await selectClient(match);
      return;
    }
    try {
      await selectClient(await _clients.getClient(id));
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
  }

  Future<void> reloadSites() async {
    final c = client.value;
    if (c == null) {
      sites.clear();
      selectedSiteId.value = null;
      return;
    }
    try {
      sites.assignAll(await _clients.listSites(c.id));
      selectedSiteId.value =
          sites.where((s) => s.isPrimary).firstOrNull?.id ??
          sites.firstOrNull?.id;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      sites.clear();
    }
  }

  void setMode(UnifiedSupportMode value) {
    mode.value = value;
    errorMessage.value = null;
  }

  void setSupportItem({
    required String? supportItemCode,
    required String? supportItemName,
    bool userInitiated = false,
  }) {
    if (userInitiated) {
      _supportItemUserChanged = true;
      _supportItemPrefilledFromStanding = false;
    }
    this.supportItemCode.value = supportItemCode;
    this.supportItemName.value = supportItemName;
  }

  void toggleFormTemplate(String id) {
    if (selectedFormTemplateIds.contains(id)) {
      selectedFormTemplateIds.remove(id);
    } else {
      selectedFormTemplateIds.add(id);
    }
  }

  void toggleWeekday(int day) {
    weekdays.contains(day) ? weekdays.remove(day) : weekdays.add(day);
  }

  void setRequiredSlots(String raw) {
    requiredSlots.value = parseRequiredSlots(raw);
  }

  void incrementSlots() {
    if (requiredSlots.value < kRequiredSlotsUiMax) requiredSlots.value++;
  }

  void decrementSlots() {
    if (requiredSlots.value > 1) requiredSlots.value--;
  }

  /// Pads or truncates [selectedContractorIds] to [requiredSlots] (null = Unfilled).
  void syncAssignSlots() {
    final n = requiredSlots.value;
    if (n < 1) return;
    final current = List<String?>.from(selectedContractorIds);
    if (current.length == n) return;
    if (current.length < n) {
      selectedContractorIds.assignAll([
        ...current,
        ...List<String?>.filled(n - current.length, null),
      ]);
      return;
    }
    selectedContractorIds.assignAll(current.sublist(0, n));
  }

  /// Sets one assign-step slot. Rejects the same contractor in two slots (D8).
  bool selectContractorForSlot(int index, String? contractorId) {
    syncAssignSlots();
    if (index < 0 || index >= selectedContractorIds.length) return false;
    final trimmed = contractorId?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null) {
      for (var i = 0; i < selectedContractorIds.length; i++) {
        if (i != index && selectedContractorIds[i] == value) {
          errorMessage.value =
              'That worker is already assigned to another slot.';
          // Force dropdown rebuild so FormField/Menu display matches controller.
          selectedContractorIds.refresh();
          return false;
        }
      }
    }
    errorMessage.value = null;
    // assignAll so GetX always notifies even when replacing a single index.
    final next = List<String?>.from(selectedContractorIds);
    next[index] = value;
    selectedContractorIds.assignAll(next);
    return true;
  }

  bool canGoNext() {
    errorMessage.value = null;
    switch (step.value) {
      case 0:
        if (mode.value == null) {
          errorMessage.value = 'Choose one session or ongoing support.';
          return false;
        }
        if (client.value == null) {
          errorMessage.value = 'Select a client.';
          return false;
        }
        return true;
      case 1:
        if (blocksWithoutSites) {
          errorMessage.value =
              'Add a location for this client before continuing.';
          return false;
        }
        if (selectedSiteId.value == null) {
          errorMessage.value = 'Select a client location.';
          return false;
        }
        return true;
      case 2:
        return _validateSchedule(showError: true);
      case 3:
        if (isOngoing && titleCtrl.text.trim().isEmpty) {
          errorMessage.value = 'Title is required.';
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void nextStep() {
    if (!canGoNext()) return;
    if (step.value < maxStep) {
      step.value++;
      if (step.value == scheduleStep) {
        ensureClientConflictsLoaded();
      }
      if (step.value == assignStep) {
        syncAssignSlots();
        ensureEngagementsLoaded();
        ensureAssignAvailabilityLoaded();
        ensureClientConflictsLoaded();
      }
    }
  }

  void previousStep() {
    errorMessage.value = null;
    if (step.value > 0) step.value--;
  }

  bool _validateSchedule({required bool showError}) {
    void fail(String msg) {
      if (showError) errorMessage.value = msg;
    }

    if (isOneSession) {
      if (!oneSessionEnd.value.isAfter(oneSessionStart.value)) {
        fail('End must be after start.');
        return false;
      }
      return true;
    }

    if (requiresWeekdays && weekdays.isEmpty) {
      fail('Select at least one weekday.');
      return false;
    }
    final windows = [
      TimeWindow(
        startTime: formatSupportTimeOfDay(startTime.value),
        endTime: formatSupportTimeOfDay(endTime.value),
      ),
    ];
    final windowError = validateVisitWindows(windows);
    if (windowError != null) {
      fail(windowError);
      return false;
    }
    if (endDate.value.isBefore(startDate.value)) {
      fail('End date must not be before the start date.');
      return false;
    }
    return true;
  }

  Future<void> openClientDetailsForNdis() async {
    final c = client.value;
    if (c == null) return;
    ClientsBinding().dependencies();
    if (Get.isRegistered<ClientsController>()) {
      final clientsCtrl = Get.find<ClientsController>();
      clientsCtrl.selected.value = c;
      clientsCtrl.tabIndex.value = ClientsController.tabDetails;
    }
    await Get.toNamed(AppRoutes.staffClientDetail, arguments: c);
    await _loadClientProfile(c.id);
  }

  Future<void> openAddSite() async {
    final c = client.value;
    if (c == null) return;
    ClientsBinding().dependencies();
    if (!Get.isRegistered<ClientsController>()) {
      errorMessage.value = 'Could not open add location.';
      return;
    }
    final clientsCtrl = Get.find<ClientsController>();
    clientsCtrl.selected.value = c;
    clientsCtrl.editingSite = null;
    clientsCtrl.siteNameCtrl.clear();
    clientsCtrl.siteAddressCtrl.clear();
    clientsCtrl.siteCityCtrl.clear();
    clientsCtrl.siteStateCtrl.text = 'NSW';
    clientsCtrl.siteCountryCtrl.text = 'AU';
    clientsCtrl.siteState.value = 'NSW';
    clientsCtrl.siteCountry.value = 'AU';
    clientsCtrl.sitePostalCtrl.clear();
    clientsCtrl.siteLatCtrl.clear();
    clientsCtrl.siteLngCtrl.clear();
    clientsCtrl.siteIsPrimary.value = sites.isEmpty;
    clientsCtrl.errorMessage.value = null;
    clientsCtrl.geocodeHint.value = null;
    await Get.toNamed(AppRoutes.staffClientSiteForm);
    await reloadSites();
  }

  Future<void> submit() async {
    if (isSaving.value || !canManage) return;
    errorMessage.value = null;
    if (mode.value == null || client.value == null) {
      errorMessage.value = 'Choose a client and support type.';
      step.value = 0;
      return;
    }
    if (blocksWithoutSites || selectedSiteId.value == null) {
      errorMessage.value = 'Select a client location.';
      step.value = locationStep;
      return;
    }
    if (!_validateSchedule(showError: true)) {
      step.value = scheduleStep;
      return;
    }
    if (isOngoing && titleCtrl.text.trim().isEmpty) {
      errorMessage.value = 'Title is required.';
      step.value = detailsStep;
      return;
    }

    syncAssignSlots();
    syncTaskTemplateFromInstructions();

    isSaving.value = true;
    try {
      if (isOneSession) {
        await _submitOneSession();
      } else {
        await _submitOngoing();
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _submitOneSession() async {
    final c = client.value!;
    final support = await _jobs.ensureOngoingSupport(c.id);
    final code = _pairedSupportItemCode(
      supportItemCode.value,
      supportItemName.value,
    );
    final name = _pairedSupportItemName(
      supportItemCode.value,
      supportItemName.value,
    );
    if (code != null && name != null) {
      await _jobs.patchJobSupportItem(
        support.id,
        SupportItemPatch(supportItemCode: code, supportItemName: name),
      );
    }
    await _attachSelectedTemplates(support.id);
    final ids = filledContractorIds;
    final tasks = List<TaskTemplateItem>.from(taskTemplate);
    await _shifts.createShift(
      ShiftCreateRequest(
        jobId: support.id,
        scheduledStart: oneSessionStart.value,
        scheduledEnd: oneSessionEnd.value,
        requiredSlots: requiredSlots.value,
        // D6 intentional: assigned workers ⇒ published even if toggle off.
        status: (publishImmediately.value || ids.isNotEmpty)
            ? 'published'
            : 'draft',
        contractorIds: ids,
        taskTemplate: tasks,
      ),
    );
    _goToRoster(jobId: support.id, clientId: c.id);
  }

  Future<void> _submitOngoing() async {
    final c = client.value!;
    final String rrule;
    try {
      rrule = compileRecurrenceRrule(
        frequency: frequency.value,
        weekdays: weekdays,
      );
    } on ArgumentError {
      errorMessage.value = 'Select at least one weekday.';
      step.value = scheduleStep;
      return;
    }
    final tz = await _resolveTenantTimezone();
    final horizon = tenantHorizonWindowUtc(DateTime.now().toUtc(), tz);
    final created = await _jobs.createOngoingSupport(
      OngoingSupportCreateRequest(
        clientId: c.id,
        title: titleCtrl.text.trim(),
        clientSiteId: selectedSiteId.value,
        contractorIds: filledContractorIds,
        rrule: rrule,
        dtstart: startDate.value,
        until: recurrenceUntilInstant(endDate.value),
        requiredSlots: requiredSlots.value,
        timeWindows: [
          TimeWindow(
            startTime: formatSupportTimeOfDay(startTime.value),
            endTime: formatSupportTimeOfDay(endTime.value),
          ),
        ],
        horizonFrom: horizon.from,
        horizonTo: horizon.to,
        supportItemCode: _pairedSupportItemCode(
          supportItemCode.value,
          supportItemName.value,
        ),
        supportItemName: _pairedSupportItemName(
          supportItemCode.value,
          supportItemName.value,
        ),
        taskTemplate: List<TaskTemplateItem>.from(taskTemplate),
      ),
    );
    await _attachSelectedTemplates(created.job.id);
    _goToRoster(jobId: created.job.id, clientId: c.id);
  }

  Future<void> _attachSelectedTemplates(String jobId) async {
    for (final id in selectedFormTemplateIds) {
      try {
        await _jobs.addFormCatalog(jobId, id);
      } catch (_) {
        // Best-effort; support create already succeeded.
      }
    }
  }

  void _goToRoster({required String jobId, required String clientId}) {
    final arguments = {
      'skipHorizonOnce': true,
      'job_id': jobId,
      'client_id': clientId,
    };
    if (_onNavigate != null) {
      _onNavigate(AppRoutes.staffVisits, arguments);
      return;
    }
    Get.offNamed(AppRoutes.staffVisits, arguments: arguments);
  }

  String? _pairedSupportItemCode(String? code, String? name) {
    final c = code?.trim();
    final n = name?.trim();
    if (c == null || c.isEmpty || n == null || n.isEmpty) return null;
    return c;
  }

  String? _pairedSupportItemName(String? code, String? name) {
    final c = code?.trim();
    final n = name?.trim();
    if (c == null || c.isEmpty || n == null || n.isEmpty) return null;
    return n;
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
