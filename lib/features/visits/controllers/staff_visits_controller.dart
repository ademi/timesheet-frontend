import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../engagements/data/models/engagement_models.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../jobs/data/models/job_models.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../shifts/data/models/shift_models.dart';
import '../../shifts/data/repositories/shifts_repository.dart';
import '../data/models/visit_models.dart';
import '../data/repositories/visits_repository.dart';

class StaffVisitsController extends GetxController {
  StaffVisitsController({
    required VisitsRepository repository,
    required ShiftsRepository shiftsRepository,
    required JobsRepository jobsRepository,
    required EngagementsRepository engagementsRepository,
    required SessionService session,
  }) : _repository = repository,
       _shiftsRepository = shiftsRepository,
       _jobsRepository = jobsRepository,
       _engagementsRepository = engagementsRepository,
       _session = session;

  final VisitsRepository _repository;
  final ShiftsRepository _shiftsRepository;
  final JobsRepository _jobsRepository;
  final EngagementsRepository _engagementsRepository;
  final SessionService _session;

  final shifts = <ShiftOut>[].obs;
  final jobs = <JobOut>[].obs;
  final engagements = <EngagementOut>[].obs;
  final selected = Rxn<VisitOut>();
  final selectedShift = Rxn<ShiftOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isRefreshing = false.obs;
  final errorMessage = RxnString();

  /// Board range: default current local day → +7 days.
  final rangeStart = DateTime.now().obs;
  final jobIdFilter = ''.obs;
  final statusFilter = ''.obs;
  bool pendingCreateShift = false;

  bool get canManage => _session.hasPermission(AppPermissions.shiftsManage);
  bool get canRead =>
      _session.hasPermission(AppPermissions.shiftsRead) ||
      _session.hasPermission(AppPermissions.shiftsManage) ||
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  List<EngagementOut> get assignableEngagements => engagements
      .where((e) => e.isActive || e.isApproved || e.isPendingDocs)
      .toList(growable: false);

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
      final v = args['visit'];
      if (v is VisitOut) selected.value = v;
      final shift = args['shift'];
      if (shift is ShiftOut) selectedShift.value = shift;
      if (args['job_id'] != null) {
        jobIdFilter.value = args['job_id'].toString();
      }
      pendingCreateShift = args['create'] == true;
      return;
    }
    if (args is VisitOut) selected.value = args;
    if (args is ShiftOut) selectedShift.value = args;
  }

  bool consumePendingCreateShift() {
    if (!pendingCreateShift) return false;
    pendingCreateShift = false;
    return true;
  }

  /// Only entry point for roster board list fetch.
  Future<void> ensureBoardLoaded() async {
    await loadJobs();
    await loadEngagements();
    await load();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing shifts.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _shiftsRepository.listShifts(
        from: _fromUtc,
        to: _toUtc,
        jobId:
            jobIdFilter.value.trim().isEmpty ? null : jobIdFilter.value.trim(),
      );
      final status = statusFilter.value.trim();
      final filtered =
          status.isEmpty
              ? list
              : list.where((s) => s.status == status).toList(growable: false);
      filtered.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      shifts.assignAll(filtered);
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
      // Optional filter list.
    }
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

  void shiftRange(int days) {
    rangeStart.value = rangeStart.value.add(Duration(days: days));
    load();
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

  Future<void> assignSelectedShift(String contractorId) async {
    final shift = selectedShift.value;
    if (shift == null) return;
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
