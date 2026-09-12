import 'package:get/get.dart';

import '../../billing/bindings/billing_binding.dart';
import '../../billing/data/repositories/ndis_catalogue_repository.dart';
import '../../jobs/bindings/jobs_binding.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../visits/bindings/visits_binding.dart';
import '../data/repositories/shifts_repository.dart';
import 'group_shift_publish_args.dart';
import 'group_shift_publish_controller.dart';

class GroupShiftPublishBinding extends Bindings {
  @override
  void dependencies() {
    VisitsBinding.ensureShared();
    JobsBinding.ensureShared();
    BillingBinding.ensureShared();
    if (!Get.isRegistered<ShiftsRepository>()) return;
    if (!Get.isRegistered<JobsRepository>()) return;
    if (!Get.isRegistered<NdisCatalogueRepository>()) return;

    final args = GroupShiftPublishArgs.fromRaw(Get.arguments);
    if (args == null) return;

    Get.put(
      GroupShiftPublishController(
        shiftsRepository: Get.find<ShiftsRepository>(),
        jobsRepository: Get.find<JobsRepository>(),
        catalogueRepository: Get.find<NdisCatalogueRepository>(),
        args: args,
      ),
    );
  }
}
