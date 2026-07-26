import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/clients_controller.dart';

class ClientsListView extends GetView<ClientsController> {
  const ClientsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      floatingActionButton: Obx(() {
        if (!controller.canManage) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: controller.openCreate,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          icon: const Icon(Icons.add),
          label: const Text('Add client'),
        );
      }),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (err != null) ...[
                _ErrorBox(err),
                const SizedBox(height: 12),
              ],
              if (controller.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No clients yet.'),
                ),
              for (final c in controller.items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(c.fullName),
                    subtitle: Text(
                      '${c.status}'
                      '${c.email != null ? ' · ${c.email}' : ''}'
                      '${c.phone != null ? ' · ${c.phone}' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => controller.openDetail(c),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
