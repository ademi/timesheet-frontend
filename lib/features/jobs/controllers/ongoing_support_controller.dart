import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../core/time/tenant_civil_time.dart';
import '../../../shared/utils/name_sort.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../payroll/controllers/staff_tenant_settings_controller.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../data/models/job_models.dart';
import '../data/repositories/jobs_repository.dart';
import '../utils/job_copy.dart';
import '../utils/recurrence_rrule_builder.dart';
import '../utils/time_window_utils.dart';
import 'recurrence_workers_selection.dart';

class OngoingSupportController extends GetxController
    with RecurrenceWorkersSelection {
  OngoingSupportController({
    required JobsRepository jobsRepository,
    required ClientsRepository clientsRepository,
    required EngagementsRepository engagementsRepository,
    required SessionService session,
    PayrollRepository? payroll,
    ClientOut? client,
    void Function(String route, dynamic arguments)? onNavigate,
  }) : _jobs = jobsRepository,
       _clients = clientsRepository,
       _engagements = engagementsRepository,
       _session = session,
       _payroll = payroll,
       _initialClient = client,
       _onNavigate = onNavigate;

  final JobsRepository _jobs;
  final ClientsRepository _clients;
  final EngagementsRepository _engagements;
  final SessionService _session;
  final PayrollRepository? _payroll;
  final ClientOut? _initialClient;
  final void Function(String route, dynamic arguments)? _onNavigate;

  late ClientOut client;

  final titleCtrl = TextEditingController();
  final startTimeCtrl = TextEditingController(text: '09:00');
  final endTimeCtrl = TextEditingController(text: '12:00');

  // Always use client site mode — the "Where" toggle has been removed from the UI.
  final locationMode = 'site'.obs;
  final selectedSiteId = RxnString();
  final selectedBranchId = RxnString();
  final frequency = RecurrenceFrequency.weekly.obs;
  final weekdays = <int>{DateTime.monday}.obs;
  final startDate = DateTime.now().obs;
  final endDate = Rx<DateTime>(
    defaultRecurrenceEndDate(DateTime.now()),
  );
  final requiredSlots = 1.obs;
  final supportItemCode = RxnString();
  final supportItemName = RxnString();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final sites = <ClientSiteOut>[].obs;
  final branches = <BranchOut>[].obs;
  final engagements = <EngagementOut>[].obs;

  bool get canManage => _session.hasPermission(AppPermissions.jobsManage);

  bool get requiresWeekdays =>
      frequency.value == RecurrenceFrequency.weekly ||
      frequency.value == RecurrenceFrequency.fortnightly;

  bool get isHomeMode => locationMode.value == 'site';

  bool get blocksHomeWithoutSites => isHomeMode && sites.isEmpty;

  bool get blocksBranchWithoutBranches =>
      locationMode.value == 'branch' && branches.isEmpty;

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
      if (slots > 1) clearSelectedContractors();
    });
    load();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    startTimeCtrl.dispose();
    endTimeCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    errorMessage.value = null;
    final arg = _initialClient ?? Get.arguments;
    if (arg is! ClientOut) {
      errorMessage.value = 'Client is required.';
      return;
    }
    client = arg;
    if (titleCtrl.text.trim().isEmpty) {
      titleCtrl.text = defaultOngoingTitle(client.fullName);
    }
    isLoading.value = true;
    try {
      try {
        sites.assignAll(await _clients.listSites(client.id));
      } on AppFailure catch (e) {
        errorMessage.value = e.message;
        sites.clear();
      }
      try {
        branches.assignAll(await _jobs.listBranches());
      } catch (_) {
        branches.clear();
      }
      try {
        engagements.assignAll(await _engagements.listTenantEngagements());
      } catch (_) {
        engagements.clear();
      }
      selectedSiteId.value ??=
          sites.where((s) => s.isPrimary).firstOrNull?.id ??
          sites.firstOrNull?.id;
      selectedBranchId.value ??= branches.firstOrNull?.id;
    } finally {
      isLoading.value = false;
    }
  }

  void setSupportItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) {
    this.supportItemCode.value = supportItemCode;
    this.supportItemName.value = supportItemName;
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

  void toggleWeekday(int day) {
    weekdays.contains(day) ? weekdays.remove(day) : weekdays.add(day);
  }

  Future<void> submit() async {
    if (isSaving.value) return;
    errorMessage.value = null;
    if (blocksHomeWithoutSites) {
      errorMessage.value =
          'Add a site for this client before starting ongoing support.';
      return;
    }
    if (blocksBranchWithoutBranches) {
      errorMessage.value = 'No branches in this organisation.';
      return;
    }
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      errorMessage.value = 'Title is required.';
      return;
    }
    if (isHomeMode && selectedSiteId.value == null) {
      errorMessage.value = 'Select a client site.';
      return;
    }
    if (!isHomeMode && selectedBranchId.value == null) {
      errorMessage.value = 'Select a branch.';
      return;
    }
    if (requiresWeekdays && weekdays.isEmpty) {
      errorMessage.value = 'Select at least one weekday.';
      return;
    }
    final windows = [
      TimeWindow(
        startTime: startTimeCtrl.text.trim(),
        endTime: endTimeCtrl.text.trim(),
      ),
    ];
    final windowError = validateVisitWindows(windows);
    if (windowError != null) {
      errorMessage.value = windowError;
      return;
    }
    if (endDate.value.isBefore(startDate.value)) {
      errorMessage.value = 'End date must not be before the start date.';
      return;
    }
    final String rrule;
    try {
      rrule = compileRecurrenceRrule(
        frequency: frequency.value,
        weekdays: weekdays,
      );
    } on ArgumentError {
      errorMessage.value = 'Select at least one weekday.';
      return;
    }
    final tz = await _resolveTenantTimezone();
    final horizon = tenantHorizonWindowUtc(DateTime.now().toUtc(), tz);
    isSaving.value = true;
    try {
      final created = await _jobs.createOngoingSupport(
        OngoingSupportCreateRequest(
          clientId: client.id,
          title: title,
          clientSiteId: isHomeMode ? selectedSiteId.value : null,
          branchId: isHomeMode ? null : selectedBranchId.value,
          contractorIds: filledContractorIds,
          rrule: rrule,
          dtstart: startDate.value,
          until: recurrenceUntilInstant(endDate.value),
          requiredSlots: requiredSlots.value,
          timeWindows: windows,
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
        ),
      );
      _goToRoster(jobId: created.job.id, clientId: client.id);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
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
