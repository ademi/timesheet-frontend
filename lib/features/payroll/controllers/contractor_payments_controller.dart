import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';

/// Contractor payments via visits `payment_status` (no own-batches API yet).
class ContractorPaymentsController extends GetxController {
  ContractorPaymentsController({
    required VisitsRepository visits,
    required SessionService session,
  })  : _visits = visits,
        _session = session;

  final VisitsRepository _visits;
  final SessionService _session;

  final visits = <VisitOut>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final paymentFilter = 'unpaid'.obs;

  bool get canView =>
      _session.hasPermission(AppPermissions.paymentsViewOwn) ||
      _session.hasPermission(AppPermissions.visitsRead);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (!canView) {
      errorMessage.value = 'Missing permission to view payment status.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final now = DateTime.now().toUtc();
      final from = now.subtract(const Duration(days: 180));
      final list = await _visits.listVisits(
        from: from,
        to: now.add(const Duration(days: 1)),
        paymentStatus: paymentFilter.value,
      );
      list.sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
      visits.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(String status) {
    paymentFilter.value = status;
    load();
  }
}
