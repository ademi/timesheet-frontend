import 'package:get/get.dart';

import '../../../../core/services/session_service.dart';
import '../../../clients/bindings/clients_binding.dart';
import '../../../clients/data/repositories/clients_repository.dart';
import '../../../engagements/data/repositories/engagements_repository.dart';
import '../../../jobs/bindings/jobs_binding.dart';
import '../../../jobs/data/repositories/jobs_repository.dart';
import '../../../shifts/data/repositories/shifts_repository.dart';
import '../../../visits/bindings/visits_binding.dart';
import '../../data/composer_facade.dart';
import '../../domain/roster_composer_args.dart';
import 'roster_composer_controller.dart';

class RosterComposerBinding extends Bindings {
  @override
  void dependencies() {
    JobsBinding.ensureShared();
    VisitsBinding.ensureShared();
    ClientsBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ShiftsRepository>()) return;
    if (!Get.isRegistered<ClientsRepository>()) return;
    if (!Get.isRegistered<JobsRepository>()) return;

    final facade = ComposerFacade(
      shifts: Get.find<ShiftsRepository>(),
      jobs: Get.find<JobsRepository>(),
    );

    Get.put(
      RosterComposerController(
        facade: facade,
        clientsRepository: Get.find<ClientsRepository>(),
        session: Get.find<SessionService>(),
        engagementsRepository:
            Get.isRegistered<EngagementsRepository>()
                ? Get.find<EngagementsRepository>()
                : null,
        args: RosterComposerArgs.fromRaw(Get.arguments),
      ),
    );
  }
}
