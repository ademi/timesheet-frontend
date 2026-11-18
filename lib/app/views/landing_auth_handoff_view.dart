import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/landing_auth_handoff_controller.dart';
import '../themes/app_colors.dart';

/// Brief splash while landing-page hash tokens are applied.
class LandingAuthHandoffView extends StatelessWidget {
  const LandingAuthHandoffView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<LandingAuthHandoffController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Obx(() {
          if (c.errorMessage.value != null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                c.errorMessage.value!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            );
          }
          return const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.brand),
              SizedBox(height: 16),
              Text(
                'Opening your dashboard…',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          );
        }),
      ),
    );
  }
}
