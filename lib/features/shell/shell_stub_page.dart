import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/controllers/auth_controller.dart';
import '../../app/themes/app_colors.dart';

/// Placeholder content for S0 shell destinations.
class ShellStubPage extends StatelessWidget {
  const ShellStubPage({
    super.key,
    required this.title,
    this.subtitle = 'Stub — feature UI lands in a later slice.',
    this.showLogout = true,
  });

  final String title;
  final String subtitle;
  final bool showLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (showLogout && Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_rounded,
                size: 48,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.textDark),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
