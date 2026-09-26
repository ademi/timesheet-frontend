import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
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
  SilHouseDetailController(this._repo, {required this.houseId});

  final SilRepository _repo;
  final String houseId;

  final bundle = Rxn<SilHouseBundleOut>();
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  Future<void> refresh() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      bundle.value = await _repo.getHouse(houseId);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
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
}
