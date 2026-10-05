import 'package:get/get.dart';

import '../../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../../core/services/session_service.dart';
import '../../../billing/bindings/billing_binding.dart';
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
    BillingBinding.ensureShared();
    if (!Get.isRegistered<SessionService>()) return;
    if (!Get.isRegistered<ShiftsRepository>()) return;
    if (!Get.isRegistered<ClientsRepository>()) return;
    if (!Get.isRegistered<JobsRepository>()) return;

    final facade = ComposerFacade(
      shifts: Get.find<ShiftsRepository>(),
      jobs: Get.find<JobsRepository>(),
    );

    // Prefer GoRouter-synced args when present (web), else GetX arguments.
    // Query/path params (synced into Get.parameters) fill gaps on web refresh.
    final raw = routeArguments() ?? Get.arguments;
    final args = RosterComposerArgs.fromRawAndParams(
      raw,
      params: {
        'id': routeParam('id'),
        'shiftId': routeParam('shiftId'),
        'shift_id': routeParam('shift_id'),
        'clientId': routeParam('clientId'),
        'client_id': routeParam('client_id'),
        'jobId': routeParam('jobId'),
        'job_id': routeParam('job_id'),
        'mode': routeParam('mode'),
        'preset': routeParam('preset'),
        'focus': routeParam('focus'),
        'focusSection': routeParam('focusSection'),
        'participantId': routeParam('participantId'),
        'participant_id': routeParam('participant_id'),
        'participantName': routeParam('participantName'),
        'participant_name': routeParam('participant_name'),
        'ruleId': routeParam('ruleId'),
        'rule_id': routeParam('rule_id'),
        'recurrenceRuleId': routeParam('recurrenceRuleId'),
        'repeat': routeParam('repeat'),
      },
    );

    if (Get.isRegistered<RosterComposerController>()) {
      Get.delete<RosterComposerController>(force: true);
    }
    Get.put(
      RosterComposerController(
        facade: facade,
        clientsRepository: Get.find<ClientsRepository>(),
        session: Get.find<SessionService>(),
        engagementsRepository:
            Get.isRegistered<EngagementsRepository>()
                ? Get.find<EngagementsRepository>()
                : null,
        args: args,
      ),
    );
  }
}
