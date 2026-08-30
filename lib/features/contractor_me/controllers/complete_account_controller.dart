import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';

/// Legacy route — redirects to Profile where contractors edit CRM + ABN/payment.
class CompleteAccountController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.offNamed(AppRoutes.contractorProfile);
    });
  }
}
