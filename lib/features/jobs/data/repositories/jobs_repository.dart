import '../../../../shared/utils/name_sort.dart';
import '../../../billing/data/models/billing_models.dart';
import '../datasources/jobs_remote_datasource.dart';
import '../models/job_models.dart';

class JobsRepository {
  JobsRepository({required JobsRemoteDataSource remote}) : _remote = remote;

  final JobsRemoteDataSource _remote;

  Future<List<JobOut>> listJobs() async {
    final jobs = List<JobOut>.of(await _remote.listJobs());
    jobs.sort((a, b) {
      final byClient = compareNames(
        a.clientName ?? 'No client',
        b.clientName ?? 'No client',
      );
      if (byClient != 0) return byClient;
      return compareNames(a.title, b.title);
    });
    return jobs;
  }
  Future<JobOut> getJob(String jobId) => _remote.getJob(jobId);
  Future<JobOut> createJob(JobCreateRequest body) => _remote.createJob(body);
  Future<JobOut> updateJobStatus(String jobId, String status) =>
      _remote.updateJobStatus(jobId, status);
  Future<JobOut> patchJobSupportItem(String jobId, SupportItemPatch body) =>
      _remote.patchJobSupportItem(jobId, body);
  Future<List<JobFormCatalogOut>> listFormCatalog(String jobId) async =>
      sortedByName(await _remote.listFormCatalog(jobId), (c) => c.name);
  Future<void> addFormCatalog(String jobId, String formTemplateId) =>
      _remote.addFormCatalog(jobId, formTemplateId);

  Future<List<RecurrenceRuleOut>> listRecurrenceRules(String jobId) =>
      _remote.listRecurrenceRules(jobId);
  Future<RecurrenceRuleOut> createRecurrenceRule(
    String jobId,
    RecurrenceRuleCreateRequest body,
  ) =>
      _remote.createRecurrenceRule(jobId, body);
  Future<RecurrenceRuleOut> patchRecurrenceRule({
    required String jobId,
    required String ruleId,
    required bool isActive,
  }) =>
      _remote.patchRecurrenceRule(
        jobId: jobId,
        ruleId: ruleId,
        isActive: isActive,
      );
  Future<GenerateVisitsResponse> generateVisits({
    required String jobId,
    required String ruleId,
    required GenerateVisitsRequest body,
    required String idempotencyKey,
  }) =>
      _remote.generateVisits(
        jobId: jobId,
        ruleId: ruleId,
        body: body,
        idempotencyKey: idempotencyKey,
      );
  Future<void> createManualVisit(
    String jobId,
    ManualVisitCreateRequest body,
  ) =>
      _remote.createManualVisit(jobId, body);

  Future<List<FormTemplateOut>> listFormTemplates({
    String? clientId,
    bool tenantLevel = false,
  }) async =>
      sortedByName(
        await _remote.listFormTemplates(
          clientId: clientId,
          tenantLevel: tenantLevel,
        ),
        (t) => t.name,
      );
  Future<FormTemplateOut> createFormTemplate(FormTemplateCreateRequest body) =>
      _remote.createFormTemplate(body);
  Future<FormTemplateOut> patchFormTemplate(
    String id, {
    String? name,
    bool? isActive,
    Map<String, dynamic>? schemaJson,
  }) =>
      _remote.patchFormTemplate(
        id,
        name: name,
        isActive: isActive,
        schemaJson: schemaJson,
      );
  Future<void> deleteFormTemplate(String id) =>
      _remote.deleteFormTemplate(id);

  Future<List<BranchOut>> listBranches() async =>
      sortedByName(await _remote.listBranches(), (b) => b.name);

  Future<HorizonOut> ensureHorizon(HorizonRequest body) =>
      _remote.ensureHorizon(body);

  Future<OngoingSupportOut> createOngoingSupport(
    OngoingSupportCreateRequest body,
  ) =>
      _remote.createOngoingSupport(body);

  Future<JobOut> getOngoingSupport(String clientId) =>
      _remote.getOngoingSupport(clientId);

  Future<JobOut> ensureOngoingSupport(String clientId, {String? title}) =>
      _remote.ensureOngoingSupport(clientId, title: title);

  Future<SplitRecurrenceOut> splitRecurrenceFrom({
    required String jobId,
    required String ruleId,
    required SplitRecurrenceRequest body,
  }) =>
      _remote.splitRecurrenceFrom(jobId: jobId, ruleId: ruleId, body: body);
}
