import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/routes/middlewares/actor_guard.dart';
import '../../app/routes/middlewares/auth_guard.dart';
import 'bindings/complete_account_binding.dart';
import 'views/complete_account_view.dart';

abstract final class ContractorMePages {
  ContractorMePages._();

  static List<GetPage> get routes => [
        GetPage(
          name: AppRoutes.contractorCompleteAccount,
          middlewares: [AuthGuard(), ActorGuard()],
          binding: CompleteAccountBinding(),
          page: () => const CompleteAccountView(),
          transition: Transition.fadeIn,
        ),
      ];
}
