import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/jobs_controller.dart';

class JobsListView extends GetView<JobsController> {
  const JobsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: shellAppBarActions(
          leadingActions: [
            IconButton(
              tooltip: 'Form templates',
              onPressed: controller.openFormTemplatesAndRefresh,
              icon: const Icon(Icons.description_outlined),
            ),
          ],
        ),
      ),
      floatingActionButton: !controller.canManage
          ? null
          : FloatingActionButton.extended(
              onPressed: controller.openCreate,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add job'),
            ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        if (controller.isLoading.value && controller.jobs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (err != null) ...[
                _ErrorBox(err),
                const SizedBox(height: 12),
              ],
              if (controller.jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No jobs yet.'),
                ),
              for (final job in controller.jobs)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(job.title),
                    subtitle: Text(
                      '${job.kind} · ${job.status}'
                      '${job.clientSiteId != null ? ' · site' : ''}'
                      '${job.branchId != null ? ' · branch' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => controller.openDetail(job),
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
