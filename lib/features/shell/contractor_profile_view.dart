import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/controllers/auth_controller.dart';
import '../../app/routes/app_routes.dart';
import '../../app/themes/app_colors.dart';

/// Minimal contractor profile with S9 payments entry (full profile in S10).
class ContractorProfileView extends StatelessWidget {
  const ContractorProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('My payments'),
            subtitle: const Text('Visit payment status (paid / unpaid)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Get.toNamed(AppRoutes.contractorPayments),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Consent withdraw, privacy export, and tenant switch land in S10.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
