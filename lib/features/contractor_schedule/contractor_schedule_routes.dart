import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import '../shell/contractor_shell.dart';
import 'bindings/contractor_schedule_binding.dart';
import 'views/contractor_schedule_view.dart';

abstract final class ContractorSchedulePages {
  ContractorSchedulePages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.contractorSchedule,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: ContractorScheduleBinding(),
          page: () => contractorShellPage(const ContractorScheduleView()),
          transition: Transition.fadeIn,
        ),
      ];
}
