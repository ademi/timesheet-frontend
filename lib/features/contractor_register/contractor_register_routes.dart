import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import 'bindings/contractor_register_binding.dart';
import 'views/contractor_register_view.dart';

/// Public contractor register route (S1).
abstract final class ContractorRegisterPages {
  ContractorRegisterPages._();

  static final GetPage page = GetPage(
    name: AppRoutes.contractorRegister,
    page: () => const ContractorRegisterView(),
    binding: ContractorRegisterBinding(),
    transition: Transition.fadeIn,
  );
}
