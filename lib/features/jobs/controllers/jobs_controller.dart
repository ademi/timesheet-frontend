import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/name_sort.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../billing/data/models/billing_models.dart';
import '../data/models/job_models.dart';
import '../data/repositories/jobs_repository.dart';

class JobsController extends GetxController {
  JobsController({
    required JobsRepository repository,
    required ClientsRepository clientsRepository,
    required EngagementsRepository engagementsRepository,
    required SessionService session,
  }) : _repository = repository,
       _clients = clientsRepository,
       _engagements = engagementsRepository,
       _session = session;

  final JobsRepository _repository;
  final ClientsRepository _clients;
  final EngagementsRepository _engagements;
  final SessionService _session;

  final jobs = <JobOut>[].obs;
  final formTemplates = <FormTemplateOut>[].obs;
  final clients = <ClientOut>[].obs;
  final branches = <BranchOut>[].obs;
  final sites = <ClientSiteOut>[].obs;
  final engagements = <EngagementOut>[].obs;
  final rules = <RecurrenceRuleOut>[].obs;

  /// Attached templates from `GET /v1/jobs/{id}/form-catalog`.
  final formCatalog = <JobFormCatalogOut>[].obs;

  final isLoading = false.obs;
  final isSaving = false.obs;
  final isGenerating = false.obs;
  final isFillingHorizon = false.obs;
  final isLoadingSites = false.obs;
  final errorMessage = RxnString();
  final clientSiteWarning = RxnString();
  final lastGenerate = Rxn<GenerateVisitsResponse>();

  final selected = Rxn<JobOut>();
  final tabIndex = 0.obs;

  // Create job form
  final titleCtrl = TextEditingController();
  final kind = 'standing'.obs;
  final locationMode = 'site'.obs; // site | branch
  final selectedClientId = RxnString();
  final selectedSiteId = RxnString();
  final selectedBranchId = RxnString();
  final geofenceMode = 'informational'.obs;
  final geofenceRadiusCtrl = TextEditingController(text: '100');
  final supportItemCode = RxnString();
  final supportItemName = RxnString();

  /// Job detail NDIS default (synced from [selected]; drives picker display).
  final editingSupportItemCode = RxnString();
  final editingSupportItemName = RxnString();

  // Recurrence / manual visit
  final selectedContractorId = RxnString();
  final generatePartial = false.obs;

  // Manual visit
  final manualTaskCtrl = TextEditingController();

  final _generateIdempotencyKeys = <String, String>{};

  bool get canManage => _session.hasPermission(AppPermissions.jobsManage);
  bool get canRead => _session.hasPermission(AppPermissions.jobsRead);
  bool get canFillHorizon =>
      canManage && rules.any((rule) => rule.isActive);

  List<String> get _activeRuleIds =>
      rules
          .where((rule) => rule.isActive)
          .map((rule) => rule.id)
          .toList(growable: false);

  bool get canManageVisits =>
      _session.hasPermission(AppPermissions.visitsManage);
  bool get canManageForms =>
      _session.hasPermission(AppPermissions.clientsManage);

  List<EngagementOut> get assignableEngagements => sortedByName(
        engagements.where((e) => e.isActive || e.isApproved || e.isPendingDocs),
        (e) => e.displayName,
      );

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    geofenceRadiusCtrl.dispose();
    manualTaskCtrl.dispose();
    super.onClose();
  }

  Future<void> loadAll() async {
    if (!canRead) {
      errorMessage.value = 'Missing jobs.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final jobList = await _repository.listJobs();
      jobs.assignAll(jobList);
      formTemplates.assignAll(
        await _repository.listFormTemplates(tenantLevel: true),
      );
      clients.assignAll(await _clients.listClients());
      try {
        branches.assignAll(await _repository.listBranches());
      } catch (_) {
        branches.clear();
      }
      try {
        engagements.assignAll(await _engagements.listTenantEngagements());
      } catch (_) {
        engagements.clear();
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void hydrateSelectedFromArgs() {
    final arg = Get.arguments;
    if (arg is JobOut) {
      selected.value = arg;
    }
  }

  /// Resolves job from args / parameters and reloads catalog + rules.
  Future<void> ensureDetailLoaded() async {
    hydrateSelectedFromArgs();
    final id =
        selected.value?.id ??
        Get.parameters['id'] ??
        (Get.arguments is String ? Get.arguments as String : null);
    if (id == null || id.isEmpty) return;
    await loadJobDetail(id);
  }

  Future<void> loadJobDetail(String jobId) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final job = await _repository.getJob(jobId);
      selected.value = job;
      _syncSupportItemEditor(job);
      final idx = jobs.indexWhere((j) => j.id == job.id);
      if (idx >= 0) {
        jobs[idx] = job;
      }
      await Future.wait([refreshRules(), refreshFormCatalog()]);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshFormCatalog() async {
    final job = selected.value;
    if (job == null) return;
    try {
      formCatalog.assignAll(await _repository.listFormCatalog(job.id));
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
  }

  bool isTemplateAttached(String templateId) =>
      formCatalog.any((c) => c.formTemplateId == templateId);

  Future<void> openFormTemplatesAndRefresh() async {
    errorMessage.value = null;
    await Get.toNamed(AppRoutes.staffFormTemplates);
    await _refreshTemplatesAndCatalog();
  }

  /// Job-scoped screen: attach catalog templates + create/edit/delete.
  Future<void> openManageTemplatesAndRefresh() async {
    errorMessage.value = null;
    final job = selected.value;
    await Get.toNamed(
      AppRoutes.staffJobManageTemplates,
      arguments: job,
      parameters: job != null ? {'id': job.id} : null,
    );
    await _refreshTemplatesAndCatalog();
  }

  Future<void> openFormTemplateEditor({FormTemplateOut? existing}) async {
    errorMessage.value = null;
    await Get.toNamed(
      AppRoutes.staffFormTemplateEditor,
      arguments: existing,
    );
    await _refreshTemplatesAndCatalog();
  }

  Future<void> _refreshTemplatesAndCatalog() async {
    isSaving.value = true;
    try {
      formTemplates.assignAll(
        await _repository.listFormTemplates(tenantLevel: true),
      );
      await refreshFormCatalog();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> onClientChanged(String? clientId) async {
    selectedClientId.value = clientId;
    selectedSiteId.value = null;
    sites.clear();
    clientSiteWarning.value = null;
    if (clientId == null) return;
    isLoadingSites.value = true;
    errorMessage.value = null;
    try {
      sites.assignAll(await _clients.listSites(clientId));
      _refreshClientSiteWarning();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoadingSites.value = false;
    }
  }

  void _refreshClientSiteWarning() {
    if (locationMode.value != 'site') {
      clientSiteWarning.value = null;
      return;
    }
    if (selectedClientId.value == null) {
      clientSiteWarning.value = null;
      return;
    }
    if (isLoadingSites.value) return;
    if (sites.isEmpty) {
      clientSiteWarning.value =
          'This client has no sites. Add a site for the client before '
          'creating a job.';
    } else {
      clientSiteWarning.value = null;
    }
  }

  /// Public wrapper for the job form when location mode changes.
  void refreshClientSiteWarning() => _refreshClientSiteWarning();

  void openCreate() {
    titleCtrl.clear();
    kind.value = 'standing';
    locationMode.value = 'site';
    selectedClientId.value = null;
    selectedSiteId.value = null;
    selectedBranchId.value = null;
    sites.clear();
    geofenceMode.value = 'informational';
    geofenceRadiusCtrl.text = '100';
    supportItemCode.value = null;
    supportItemName.value = null;
    errorMessage.value = null;
    clientSiteWarning.value = null;
    Get.toNamed(AppRoutes.staffJobForm);
  }

  Future<void> saveJob() async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      errorMessage.value = 'Title is required.';
      return;
    }
    final useSite = locationMode.value == 'site';
    if (kind.value == 'standing' && selectedClientId.value == null) {
      errorMessage.value = 'Ongoing support needs a client.';
      return;
    }
    if (useSite && selectedClientId.value != null && sites.isEmpty) {
      errorMessage.value =
          'This client has no sites. Add a site for the client before '
          'creating a job.';
      clientSiteWarning.value = errorMessage.value;
      return;
    }
    if (useSite && selectedSiteId.value == null) {
      errorMessage.value = 'Select a client site.';
      return;
    }
    if (!useSite && selectedBranchId.value == null) {
      errorMessage.value = 'Select a branch.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final created = await _repository.createJob(
        JobCreateRequest(
          kind: kind.value,
          title: title,
          clientId: selectedClientId.value,
          clientSiteId: useSite ? selectedSiteId.value : null,
          branchId: useSite ? null : selectedBranchId.value,
          geofenceMode: geofenceMode.value,
          geofenceRadiusM: int.tryParse(geofenceRadiusCtrl.text.trim()),
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
      Get.back();
      await loadAll();
      await openDetail(created);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openDetail(JobOut job) async {
    selected.value = job;
    _syncSupportItemEditor(job);
    formCatalog.clear();
    lastGenerate.value = null;
    tabIndex.value = 0;
    Get.toNamed(
      AppRoutes.staffJobDetail,
      arguments: job,
      parameters: {'id': job.id},
    );
    await loadJobDetail(job.id);
  }

  Future<void> refreshRules() async {
    final job = selected.value;
    if (job == null) return;
    try {
      rules.assignAll(await _repository.listRecurrenceRules(job.id));
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
  }

  Future<void> updateJobSupportItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) async {
    final job = selected.value;
    if (job == null || !canManage) return;
    if (supportItemCode == job.supportItemCode &&
        supportItemName == job.supportItemName) {
      return;
    }
    final previousCode = editingSupportItemCode.value;
    final previousName = editingSupportItemName.value;
    editingSupportItemCode.value = supportItemCode;
    editingSupportItemName.value = supportItemName;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.patchJobSupportItem(
        job.id,
        SupportItemPatch(
          supportItemCode: supportItemCode,
          supportItemName: supportItemName,
        ),
      );
      selected.value = updated;
      _syncSupportItemEditor(updated);
      final idx = jobs.indexWhere((j) => j.id == updated.id);
      if (idx >= 0) jobs[idx] = updated;
    } on AppFailure catch (e) {
      editingSupportItemCode.value = previousCode;
      editingSupportItemName.value = previousName;
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  void setCreateSupportItem({
    required String? supportItemCode,
    required String? supportItemName,
  }) {
    this.supportItemCode.value = supportItemCode;
    this.supportItemName.value = supportItemName;
  }

  void _syncSupportItemEditor(JobOut job) {
    editingSupportItemCode.value = job.supportItemCode;
    editingSupportItemName.value = job.supportItemName;
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

  Future<void> setStatus(String status) async {
    final job = selected.value;
    if (job == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.updateJobStatus(job.id, status);
      selected.value = updated;
      _syncSupportItemEditor(updated);
      final idx = jobs.indexWhere((j) => j.id == updated.id);
      if (idx >= 0) jobs[idx] = updated;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> attachFormTemplate(String templateId) async {
    final job = selected.value;
    if (job == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.addFormCatalog(job.id, templateId);
      await refreshFormCatalog();
      Get.snackbar(
        'Attached',
        'Form template added to job catalog.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  /// Create or update a tenant-wide form template with a full field schema.
  Future<bool> saveFormTemplate({
    String? id,
    required String name,
    required bool isActive,
    required Map<String, dynamic> schemaJson,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      errorMessage.value = 'Template name is required.';
      return false;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final FormTemplateOut saved;
      if (id == null) {
        saved = await _repository.createFormTemplate(
          FormTemplateCreateRequest(
            name: trimmed,
            schemaJson: schemaJson,
            isActive: isActive,
          ),
        );
      } else {
        saved = await _repository.patchFormTemplate(
          id,
          name: trimmed,
          isActive: isActive,
          schemaJson: schemaJson,
        );
      }

      final idx = formTemplates.indexWhere((t) => t.id == saved.id);
      if (idx >= 0) {
        formTemplates[idx] = saved;
      } else {
        try {
          formTemplates.assignAll(
            await _repository.listFormTemplates(tenantLevel: true),
          );
        } on AppFailure {
          if (!formTemplates.any((t) => t.id == saved.id)) {
            formTemplates.insert(0, saved);
          }
        }
        if (!formTemplates.any((t) => t.id == saved.id)) {
          formTemplates.insert(0, saved);
        }
      }
      formTemplates.sort((a, b) => compareNames(a.name, b.name));
      await refreshFormCatalog();
      Get.snackbar(
        id == null ? 'Created' : 'Updated',
        'Form template “$trimmed” saved.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(
        'Could not save template',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Could not save template',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteFormTemplate(String id) async {
    isSaving.value = true;
    try {
      await _repository.deleteFormTemplate(id);
      formTemplates.assignAll(
        await _repository.listFormTemplates(tenantLevel: true),
      );
      await refreshFormCatalog();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> createRecurrenceRule(RecurrenceRuleCreateRequest request) async {
    final job = selected.value;
    if (job == null) return false;
    if (!job.isStanding) {
      errorMessage.value = 'Patterns need ongoing support.';
      return false;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.createRecurrenceRule(job.id, request);
      await refreshRules();
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> toggleRuleActive(RecurrenceRuleOut rule) async {
    final job = selected.value;
    if (job == null) return;
    isSaving.value = true;
    try {
      await _repository.patchRecurrenceRule(
        jobId: job.id,
        ruleId: rule.id,
        isActive: !rule.isActive,
      );
      await refreshRules();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> fillNext14Days() async {
    if (!canFillHorizon) return;
    isFillingHorizon.value = true;
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day).toUtc();
      final to = from.add(const Duration(days: 14));
      final result = await _repository.ensureHorizon(
        HorizonRequest(from: from, to: to, ruleIds: _activeRuleIds),
      );
      final created = result.createdShiftIds.length;
      if (created > 0 && !Get.testMode) {
        Get.snackbar(
          'Roster updated',
          '$created new time${created == 1 ? '' : 's'} added.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
          colorText: AppColors.onPrimary,
        );
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isFillingHorizon.value = false;
    }
  }

  Future<void> generateForRule(RecurrenceRuleOut rule) async {
    final job = selected.value;
    if (job == null) return;
    final now = DateTime.now().toUtc();
    final from = now;
    final to = now.add(const Duration(days: 14));
    final idemKey = _generateIdempotencyKeys.putIfAbsent(
      '${rule.id}|${from.toIso8601String()}|${to.toIso8601String()}|${generatePartial.value}',
      () => 'fe-gen-${rule.id}-${now.microsecondsSinceEpoch}',
    );
    isGenerating.value = true;
    errorMessage.value = null;
    lastGenerate.value = null;
    try {
      final result = await _repository.generateVisits(
        jobId: job.id,
        ruleId: rule.id,
        body: GenerateVisitsRequest(
          from: from,
          to: to,
          partial: generatePartial.value,
        ),
        idempotencyKey: idemKey,
      );
      lastGenerate.value = result;
      Get.snackbar(
        'Generate complete',
        'Created ${result.createdShiftIds.length} shift(s), '
            '${result.createdVisitIds.length} visit(s); '
            'skipped ${result.skipped.length}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isGenerating.value = false;
    }
  }

  Future<void> createManualVisit() async {
    final job = selected.value;
    if (job == null) return;
    final contractorId = selectedContractorId.value;
    if (contractorId == null) {
      errorMessage.value = 'Select a contractor.';
      return;
    }
    final start = DateTime.now().toUtc().add(const Duration(hours: 1));
    final end = start.add(const Duration(hours: 1));
    final tasks =
        manualTaskCtrl.text
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.createManualVisit(
        job.id,
        ManualVisitCreateRequest(
          contractorId: contractorId,
          scheduledStart: start,
          scheduledEnd: end,
          taskTitles: tasks,
          formTemplateIds: formCatalog
              .map((catalogEntry) => catalogEntry.formTemplateId)
              .toList(growable: false),
        ),
      );
      Get.snackbar(
        'Visit created',
        'Manual visit scheduled (opens in Visits in S7).',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
