import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../clients/data/models/support_plan_models.dart';
import '../data/repositories/visits_repository.dart';

class VisitShiftBriefController extends GetxController {
  VisitShiftBriefController({required VisitsRepository repo}) : _repo = repo;

  final VisitsRepository _repo;

  final brief = Rxn<ShiftBriefDto>();
  final isLoading = false.obs;
  final errorMessage = RxnString();

  /// Tier-2 re-enter: reload brief for [visitId], or clear when none selected.
  void onScreenReenter({String? visitId}) {
    if (visitId == null || visitId.isEmpty) {
      brief.value = null;
      errorMessage.value = null;
      return;
    }
    // ignore: discarded_futures
    load(visitId);
  }

  Future<void> load(String visitId) async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      brief.value = await _repo.getVisitShiftBrief(visitId);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      brief.value = null;
    } finally {
      isLoading.value = false;
    }
  }
}
