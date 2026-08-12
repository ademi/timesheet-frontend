import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../jobs/data/models/job_models.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';

class StaffVisitsController extends GetxController {
  StaffVisitsController({
    required VisitsRepository repository,
    required JobsRepository jobsRepository,
    required SessionService session,
  }) : _repository = repository,
       _jobsRepository = jobsRepository,
       _session = session;

  final VisitsRepository _repository;
  final JobsRepository _jobsRepository;
  final SessionService _session;

  bool _skipBoardLoad = false;

  final visits = <VisitOut>[].obs;
  final jobs = <JobOut>[].obs;
  final selected = Rxn<VisitOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = RxnString();

  /// Board range: default current local day → +7 days.
  final rangeStart = DateTime.now().obs;
  final jobIdFilter = ''.obs;
  final statusFilter = ''.obs;

  bool get canManage => _session.hasPermission(AppPermissions.visitsManage);
  bool get canRead =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  DateTime get _fromUtc {
    final d = rangeStart.value;
    return DateTime(d.year, d.month, d.day).toUtc();
  }

  DateTime get _toUtc => _fromUtc.add(const Duration(days: 7));

  @override
  void onInit() {
    super.onInit();
    applyRouteArgs();
  }

  void applyRouteArgs() {
    final args = Get.arguments;
    if (args is Map) {
      _skipBoardLoad = args['skipBoardLoad'] == true;
      final v = args['visit'];
      if (v is VisitOut) selected.value = v;
      if (args['job_id'] != null) {
        jobIdFilter.value = args['job_id'].toString();
      }
      return;
    }
    if (args is VisitOut) selected.value = args;
  }

  /// Only entry point for board list fetch (D4-A + D8-A).
  Future<void> ensureBoardLoaded() async {
    _skipBoardLoad = false;
    await loadJobs();
    await load();
  }

  Future<void> load() async {
    if (_skipBoardLoad) return;
    if (!canRead) {
      errorMessage.value = 'Missing visits.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.listVisits(
        from: _fromUtc,
        to: _toUtc,
        jobId:
            jobIdFilter.value.trim().isEmpty ? null : jobIdFilter.value.trim(),
        status:
            statusFilter.value.trim().isEmpty
                ? null
                : statusFilter.value.trim(),
      );
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      visits.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadJobs() async {
    try {
      jobs.assignAll(await _jobsRepository.listJobs());
    } catch (_) {
      // The visit board remains usable without an optional filter list.
    }
  }

  void setJobFilter(String? jobId) {
    jobIdFilter.value = jobId ?? '';
    load();
  }

  void shiftRange(int days) {
    rangeStart.value = rangeStart.value.add(Duration(days: days));
    load();
  }

  void setStatusFilter(String? status) {
    statusFilter.value = status ?? '';
    load();
  }

  Future<void> openDetail(VisitOut visit) async {
    selected.value = visit;
    Get.toNamed(AppRoutes.staffVisitDetail, arguments: visit);
    await refreshSelected();
  }

  Future<void> refreshSelected() async {
    final id =
        selected.value?.id ??
        (Get.arguments is VisitOut ? (Get.arguments as VisitOut).id : null);
    if (id == null) return;
    isRefreshing.value = true;
    try {
      selected.value = await _repository.getVisit(id);
      final idx = visits.indexWhere((v) => v.id == id);
      if (idx >= 0 && selected.value != null) {
        visits[idx] = selected.value!;
      }
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
      return;
    }
    if (arg is Map && arg['visit'] is VisitOut) {
      selected.value = arg['visit'] as VisitOut;
    }
  }

  Future<void> cancelSelected() async {
    final visit = selected.value;
    if (visit == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.cancel(visit.id);
      await refreshSelected();
      await load();
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
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
