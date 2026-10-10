import 'package:get/get.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../core/time/tenant_civil_time.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../visits/controllers/staff_visits_controller.dart';
import '../data/models/sil_models.dart';
import '../data/repositories/sil_repository.dart';

class SilHousesController extends GetxController {
  SilHousesController(this._repo);

  final SilRepository _repo;

  final houses = <SilHouseOut>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    refreshHouses();
  }

  /// Tier-2 shell re-enter: soft list refresh.
  void onScreenReenter() {
    errorMessage.value = null;
    // ignore: discarded_futures
    refreshHouses();
  }

  Future<void> refreshHouses() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      houses.assignAll(await _repo.listHouses());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<SilHouseOut?> createHouse(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      final created = await _repo.createHouse(
        SilHouseCreateRequest(name: trimmed),
      );
      await refreshHouses();
      if (!Get.testMode) {
        AppToast.success('SIL house created', created.name);
      }
      return created;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('Could not create house', e.message);
      return null;
    }
  }
}

class SilHouseDetailController extends GetxController {
  SilHouseDetailController(
    this._repo, {
    required this.houseId,
    required ClientsRepository clientsRepository,
  }) : _clients = clientsRepository;

  final SilRepository _repo;
  final ClientsRepository _clients;
  final String houseId;

  final bundle = Rxn<SilHouseBundleOut>();
  final overlay = Rxn<SilVacancyOverlayOut>();
  final compatRules = <SilCompatRuleOut>[].obs;
  final clientCandidates = <ClientOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isLoadingClients = false.obs;
  final errorMessage = RxnString();

  Set<String> get linkedClientIds => {
    for (final m in bundle.value?.members ?? const <SilHouseMemberOut>[])
      m.clientId,
  };

  @override
  void onInit() {
    super.onInit();
    refresh();
    // ignore: discarded_futures
    loadClientCandidates();
  }

  Future<void> loadClientCandidates() async {
    isLoadingClients.value = true;
    try {
      final listed = await _clients.listClients();
      clientCandidates.assignAll([
        for (final c in listed)
          if (c.status != 'archived') c,
      ]);
    } on AppFailure catch (e) {
      if (!Get.testMode) {
        AppToast.error('Could not load clients', e.message);
      }
    } catch (_) {
      // Picker can still open empty; member link will fail clearly.
    } finally {
      isLoadingClients.value = false;
    }
  }

  Future<void> refresh() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      bundle.value = await _repo.getHouse(houseId);
      try {
        overlay.value = await _repo.getOverlay(houseId);
      } catch (_) {
        overlay.value = null;
      }
      try {
        compatRules.assignAll(await _repo.listCompatRules(houseId));
      } catch (_) {
        compatRules.clear();
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> linkMember({
    required String clientId,
    String occupancyStatus = 'present',
    String? bedLabel,
  }) async {
    final trimmedBed = bedLabel?.trim();
    isSaving.value = true;
    try {
      await _repo.upsertMember(
        houseId,
        SilHouseMemberUpsertRequest(
          clientId: clientId,
          occupancyStatus: occupancyStatus,
          bedLabel:
              trimmedBed == null || trimmedBed.isEmpty ? null : trimmedBed,
        ),
      );
      await refresh();
      if (!Get.testMode) {
        AppToast.success('Member linked', 'Client added to this house');
      }
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('Could not link member', e.message);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveCapacityCost({
    int? bedCapacity,
    double? fixedWeeklyCost,
  }) async {
    isSaving.value = true;
    try {
      await _repo.patchHouse(
        houseId,
        SilHousePatchRequest(
          bedCapacity: bedCapacity,
          fixedWeeklyCost: fixedWeeklyCost,
        ),
      );
      await refresh();
      if (!Get.testMode) {
        AppToast.success('House updated', 'Capacity / cost saved');
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('House update failed', e.message);
    } finally {
      isSaving.value = false;
    }
  }

  /// Tomorrow 09:00–11:00 in the tenant timezone (falls back to device local).
  ///
  /// Avoids `utcNow + 1 day`, which can land after the roster week’s Sunday
  /// for tenants east of UTC and make the draft look “missing”.
  (DateTime start, DateTime end) _draftFillScheduleUtc() {
    final tz =
        Get.isRegistered<SessionService>()
            ? Get.find<SessionService>().tenantTimezone.value?.trim()
            : null;
    final civilNow = tenantCivilFromUtc(DateTime.now().toUtc(), tz);
    final tomorrow = DateTime(
      civilNow.year,
      civilNow.month,
      civilNow.day,
    ).add(const Duration(days: 1));
    final startCivil = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      9,
    );
    final endCivil = startCivil.add(const Duration(hours: 2));
    return (
      tenantCivilInstantUtc(startCivil, tz),
      tenantCivilInstantUtc(endCivil, tz),
    );
  }

  Future<String?> draftFillShift() async {
    if ((bundle.value?.members ?? const []).isEmpty) {
      if (!Get.testMode) {
        AppToast.error(
          'Add a member first',
          'Draft fill shift needs a linked housemate to create the job.',
        );
      }
      return null;
    }
    isSaving.value = true;
    try {
      final (start, end) = _draftFillScheduleUtc();
      final out = await _repo.fillVacancy(
        houseId,
        SilFillVacancyRequest(
          scheduledStart: start,
          scheduledEnd: end,
        ),
      );
      await refresh();
      // Roster defaults to Live; draft fills are unpublished — surface them.
      if (Get.isRegistered<StaffVisitsController>()) {
        Get.find<StaffVisitsController>().revealDraftOnBoard(start);
      }
      if (!Get.testMode) {
        AppToast.success('Draft shift created', 'Opening shift detail…');
        AppNavigator.push(
          AppNavigator.location(
            AppRoutes.staffShiftDetail,
            query: {'id': out.shiftId},
          ),
          extra: {'id': out.shiftId},
        );
      }
      return out.shiftId;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('Fill vacancy failed', e.message);
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveRocBlock({
    required String band,
    required int workers,
    required int participants,
  }) async {
    isSaving.value = true;
    try {
      await _repo.upsertRocBlock(
        houseId,
        SilRocBlockUpsertRequest(
          band: band,
          fundedWorkerCount: workers.clamp(1, 20),
          fundedParticipantCount: participants.clamp(1, 32),
        ),
      );
      await refresh();
      if (!Get.testMode) {
        AppToast.success('ROC updated', band);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('ROC save failed', e.message);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> setOccupancy({
    required String clientId,
    required String status,
  }) async {
    isSaving.value = true;
    try {
      await _repo.upsertMember(
        houseId,
        SilHouseMemberUpsertRequest(
          clientId: clientId,
          occupancyStatus: status,
        ),
      );
      await refresh();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('Occupancy update failed', e.message);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> addCompatRule({
    required String reason,
    String severity = 'soft_warn',
    String? againstClientId,
  }) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return;
    final subjectId = againstClientId?.trim();
    if (subjectId == null || subjectId.isEmpty) {
      if (!Get.testMode) {
        AppToast.error(
          'Compat rule needs a housemate',
          'Link a member first, then choose who the rule is against.',
        );
      }
      return;
    }
    isSaving.value = true;
    try {
      await _repo.createCompatRule(
        houseId,
        SilCompatRuleCreateRequest(
          againstClientId: subjectId,
          severity: severity,
          reason: trimmed,
        ),
      );
      await refresh();
      if (!Get.testMode) {
        AppToast.success('Compat rule added', severity);
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('Compat rule failed', e.message);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> removeCompatRule(String ruleId) async {
    isSaving.value = true;
    try {
      await _repo.deleteCompatRule(houseId, ruleId);
      await refresh();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) AppToast.error('Delete failed', e.message);
    } finally {
      isSaving.value = false;
    }
  }
}
