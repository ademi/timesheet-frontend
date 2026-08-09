import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
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

  // Form template
  final templateNameCtrl = TextEditingController();

  // Recurrence / manual visit
  final selectedContractorId = RxnString();
  final generatePartial = false.obs;

  // Manual visit
  final manualTaskCtrl = TextEditingController();

  final _generateIdempotencyKeys = <String, String>{};

  bool get canManage => _session.hasPermission(AppPermissions.jobsManage);
  bool get canRead => _session.hasPermission(AppPermissions.jobsRead);
  bool get canManageVisits =>
      _session.hasPermission(AppPermissions.visitsManage);
  bool get canManageForms =>
      _session.hasPermission(AppPermissions.clientsManage);

  List<EngagementOut> get assignableEngagements => engagements
      .where((e) => e.isActive || e.isApproved || e.isPendingDocs)
      .toList(growable: false);

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    geofenceRadiusCtrl.dispose();
    templateNameCtrl.dispose();
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
    templateNameCtrl.clear();
    errorMessage.value = null;
    await Get.toNamed(AppRoutes.staffFormTemplates);
    await _refreshTemplatesAndCatalog();
  }

  /// Job-scoped screen: attach catalog templates + create/edit/delete.
  Future<void> openManageTemplatesAndRefresh() async {
    templateNameCtrl.clear();
    errorMessage.value = null;
    final job = selected.value;
    await Get.toNamed(
      AppRoutes.staffJobManageTemplates,
      arguments: job,
      parameters: job != null ? {'id': job.id} : null,
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
      errorMessage.value = 'Standing jobs require a client.';
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
      errorMessage.value = 'Select a client site (XOR with branch).';
      return;
    }
    if (!useSite && selectedBranchId.value == null) {
      errorMessage.value = 'Select a branch (XOR with client site).';
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

  Future<void> setStatus(String status) async {
    final job = selected.value;
    if (job == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.updateJobStatus(job.id, status);
      selected.value = updated;
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

  Future<void> createFormTemplate() async {
    final name = templateNameCtrl.text.trim();
    if (name.isEmpty) {
      errorMessage.value = 'Template name is required.';
      Get.snackbar(
        'Form template',
        'Enter a template name first.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      // Form Templates screen always creates tenant-wide templates
      // (`client_id` null). Do not inherit client_id from a previously
      // opened job — that hides the new row under tenant_level=true list.
      final created = await _repository.createFormTemplate(
        FormTemplateCreateRequest(
          name: name,
          schemaJson: simpleTextFormSchema(label: name),
        ),
      );
      templateNameCtrl.clear();
      try {
        formTemplates.assignAll(
          await _repository.listFormTemplates(tenantLevel: true),
        );
      } on AppFailure {
        // List refresh failed — still show the created row locally.
        if (!formTemplates.any((t) => t.id == created.id)) {
          formTemplates.insert(0, created);
        }
      }
      if (!formTemplates.any((t) => t.id == created.id)) {
        formTemplates.insert(0, created);
      }
      Get.snackbar(
        'Created',
        'Form template “$name” is ready.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(
        'Could not create template',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar(
        'Could not create template',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateFormTemplate({
    required String id,
    required String name,
    required bool isActive,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      errorMessage.value = 'Template name is required.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _repository.patchFormTemplate(
        id,
        name: trimmed,
        isActive: isActive,
      );
      final idx = formTemplates.indexWhere((t) => t.id == id);
      if (idx >= 0) {
        formTemplates[idx] = updated;
      } else {
        formTemplates.assignAll(
          await _repository.listFormTemplates(tenantLevel: true),
        );
      }
      await refreshFormCatalog();
      Get.snackbar(
        'Updated',
        'Form template “$trimmed” saved.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      Get.snackbar(
        'Could not update template',
        e.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.error,
        colorText: Colors.white,
      );
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
      errorMessage.value = 'Recurrence requires a standing job.';
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
        'Created ${result.createdVisitIds.length} visit(s); '
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
