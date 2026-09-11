import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../clients/bindings/clients_binding.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../jobs/bindings/jobs_binding.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../payroll/bindings/payroll_binding.dart';
import '../../payroll/data/repositories/payroll_repository.dart';
import '../../visits/bindings/visits_binding.dart';
import '../data/repositories/shifts_repository.dart';
import 'group_shift_book_args.dart';
import 'group_shift_book_controller.dart';

class GroupShiftBookBinding extends Bindings {
  @override
  void dependencies() {
    JobsBinding.ensureShared();
    VisitsBinding.ensureShared();
    PayrollBinding.ensureShared();
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ShiftsRepository>()) return;
    if (!Get.isRegistered<ClientsRepository>()) return;
    if (!Get.isRegistered<JobsRepository>()) return;

    final raw = Get.arguments;
    GroupShiftBookArgs? args;
    if (raw is GroupShiftBookArgs) {
      args = raw;
    } else if (raw is Map) {
      args = GroupShiftBookArgs.fromMap(raw);
    }

    Get.put(
      GroupShiftBookController(
        clientsRepository: Get.find<ClientsRepository>(),
        jobsRepository: Get.find<JobsRepository>(),
        shiftsRepository: Get.find<ShiftsRepository>(),
        session: Get.find<SessionService>(),
        payroll:
            Get.isRegistered<PayrollRepository>()
                ? Get.find<PayrollRepository>()
                : null,
        args: args,
      ),
    );
  }
}
