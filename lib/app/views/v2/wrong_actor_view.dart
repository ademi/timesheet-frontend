import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../themes/app_colors.dart';

/// Dedicated screen for `wrong_actor_type` / hard actor mismatches.
class WrongActorView extends StatelessWidget {
  const WrongActorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 56, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Wrong account type',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This account can’t use this area. Sign in with the correct account type.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDark),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (Get.isRegistered<AuthController>()) {
                    Get.find<AuthController>().logout();
                  } else {
                    Get.offAllNamed('/login');
                  }
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
