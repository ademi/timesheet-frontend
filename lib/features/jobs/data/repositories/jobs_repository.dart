import '../datasources/jobs_remote_datasource.dart';
import '../models/job_models.dart';

class JobsRepository {
  JobsRepository({required JobsRemoteDataSource remote}) : _remote = remote;

  final JobsRemoteDataSource _remote;

  Future<List<JobOut>> listJobs() => _remote.listJobs();
  Future<JobOut> getJob(String jobId) => _remote.getJob(jobId);
  Future<JobOut> createJob(JobCreateRequest body) => _remote.createJob(body);
  Future<JobOut> updateJobStatus(String jobId, String status) =>
      _remote.updateJobStatus(jobId, status);
  Future<List<JobFormCatalogOut>> listFormCatalog(String jobId) =>
      _remote.listFormCatalog(jobId);
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
  }) =>
      _remote.listFormTemplates(clientId: clientId, tenantLevel: tenantLevel);
  Future<FormTemplateOut> createFormTemplate(FormTemplateCreateRequest body) =>
      _remote.createFormTemplate(body);
  Future<FormTemplateOut> patchFormTemplate(
    String id, {
    String? name,
    bool? isActive,
  }) =>
      _remote.patchFormTemplate(id, name: name, isActive: isActive);
  Future<void> deleteFormTemplate(String id) =>
      _remote.deleteFormTemplate(id);

  Future<List<BranchOut>> listBranches() => _remote.listBranches();
}
