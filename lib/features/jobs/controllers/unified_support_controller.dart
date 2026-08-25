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
import '../data/models/job_models.dart';
import '../data/repositories/jobs_repository.dart';
import '../utils/job_copy.dart';
import '../utils/recurrence_rrule_builder.dart';
import '../utils/required_slots_input.dart';
import '../utils/schedule_hours_warn.dart';
import '../utils/time_window_utils.dart';
import '../utils/unified_support_args.dart';
import '../utils/task_title_presets.dart';
import '../widgets/care_plan_tasks_field.dart';

String formatSupportTimeOfDay(TimeOfDay time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

class UnifiedSupportController extends GetxController {
  UnifiedSupportController({
    required JobsRepository jobsRepository,
    required ClientsRepository clientsRepository,
    required EngagementsRepository engagementsRepository,
    required ShiftsRepository shiftsRepository,
    required SessionService session,
    PayrollRepository? payroll,
    UnifiedSupportArgs? args,
    void Function(String route, dynamic arguments)? onNavigate,
  }) : _jobs = jobsRepository,
       _clients = clientsRepository,
       _engagements = engagementsRepository,
       _shifts = shiftsRepository,
       _session = session,
       _payroll = payroll,
       _args = args,
       _onNavigate = onNavigate;

  final JobsRepository _jobs;
  final ClientsRepository _clients;
  final EngagementsRepository _engagements;
  final ShiftsRepository _shifts;
  final SessionService _session;
  final PayrollRepository? _payroll;
  final UnifiedSupportArgs? _args;
  final void Function(String route, dynamic arguments)? _onNavigate;

  static const int maxStep = 3;

  final step = 0.obs;
  final mode = Rxn<UnifiedSupportMode>();
  final client = Rxn<ClientOut>();

  final titleCtrl = TextEditingController();
  final taskTitlesCtrl = TextEditingController();
  final otherTitleCtrl = TextEditingController();
  final showOtherTitleField = false.obs;
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
  final selectedContractorId = RxnString();
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

  List<String> get carePlanTaskTitles => parseTaskTitles(taskTitlesCtrl.text);

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
    ever(requiredSlots, (slots) {
      if (slots > 1) selectedContractorId.value = null;
    });
    ever(oneSessionStart, (DateTime start) {
      if (!oneSessionEnd.value.isAfter(start)) {
        oneSessionEnd.value = start.add(const Duration(hours: 1));
      }
    });
    _bootstrap();
    _cacheTenantTimezone();
  }

  Future<void> _cacheTenantTimezone() async {
    scheduleWarnTimezone.value = await _resolveTenantTimezone();
  }

  String? get _tenantTimezoneForScheduleWarn => scheduleWarnTimezone.value;

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

  /// Loads client, sites, templates, and engagements for the composer.
  Future<void> load() => _bootstrap();

  @override
  void onClose() {
    titleCtrl.dispose();
    taskTitlesCtrl.dispose();
    otherTitleCtrl.dispose();
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
      try {
        engagements.assignAll(await _engagements.listTenantEngagements());
      } catch (_) {
        engagements.clear();
      }
    } finally {
      isLoading.value = false;
    }
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
    client.value = value;
    if (titleCtrl.text.trim().isEmpty) {
      titleCtrl.text = defaultOngoingTitle(value.fullName);
    }
    await Future.wait([reloadSites(), _loadClientProfile(value.id)]);
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
  }) {
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

  void onTaskPresetSelected(String? preset) {
    if (preset == null) return;
    if (preset == taskTitlePresetOther) {
      showOtherTitleField.value = true;
      return;
    }
    appendCarePlanTask(preset);
  }

  void appendCarePlanTask(String title) {
    taskTitlesCtrl.text = appendTaskTitleLine(taskTitlesCtrl.text, title);
  }

  void appendOtherCarePlanTask() {
    appendCarePlanTask(otherTitleCtrl.text);
    otherTitleCtrl.clear();
    showOtherTitleField.value = false;
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
      default:
        return true;
    }
  }

  void nextStep() {
    if (!canGoNext()) return;
    if (step.value < maxStep) step.value++;
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
      step.value = 1;
      return;
    }
    if (!_validateSchedule(showError: true)) {
      step.value = 2;
      return;
    }
    if (isOngoing && titleCtrl.text.trim().isEmpty) {
      errorMessage.value = 'Title is required.';
      step.value = 3;
      return;
    }

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
      try {
        await _jobs.patchJobSupportItem(
          support.id,
          SupportItemPatch(supportItemCode: code, supportItemName: name),
        );
      } catch (_) {}
    }
    await _attachSelectedTemplates(support.id);
    final tasks = carePlanTaskTitles;
    final contractorId = selectedContractorId.value;
    if (contractorId != null && tasks.isNotEmpty) {
      await _jobs.createManualVisit(
        support.id,
        ManualVisitCreateRequest(
          contractorId: contractorId,
          scheduledStart: oneSessionStart.value,
          scheduledEnd: oneSessionEnd.value,
          taskTitles: tasks,
          formTemplateIds: selectedFormTemplateIds.toList(growable: false),
          supportItemCode: code,
          supportItemName: name,
        ),
      );
      _goToRoster(jobId: support.id, clientId: c.id);
      return;
    }
    await _shifts.createShift(
      ShiftCreateRequest(
        jobId: support.id,
        scheduledStart: oneSessionStart.value,
        scheduledEnd: oneSessionEnd.value,
        requiredSlots: requiredSlots.value,
        status: publishImmediately.value ? 'published' : 'draft',
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
      step.value = 2;
      return;
    }
    final tz = await _resolveTenantTimezone();
    final horizon = tenantHorizonWindowUtc(DateTime.now().toUtc(), tz);
    final created = await _jobs.createOngoingSupport(
      OngoingSupportCreateRequest(
        clientId: c.id,
        title: titleCtrl.text.trim(),
        clientSiteId: selectedSiteId.value,
        contractorId: selectedContractorId.value,
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
        taskTemplate: taskTemplateFromTitles(taskTitlesCtrl.text),
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
