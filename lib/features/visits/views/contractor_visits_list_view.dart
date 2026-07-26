import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/contractor_visits_controller.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class ContractorVisitsListView extends GetView<ContractorVisitsController> {
  const ContractorVisitsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My visits'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.visits.isEmpty) {
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
              if (controller.isWeb)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Check-in / complete require the mobile app with location enabled.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              if (controller.visits.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No upcoming visits.'),
                ),
              for (final v in controller.visits)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(v.jobTitle ?? v.tenantName ?? 'Visit'),
                    subtitle: Text('${_fmt(v.scheduledStart)} · ${v.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => controller.openDetail(v),
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
