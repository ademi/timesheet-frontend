import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/utils/name_sort.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/jobs_controller.dart';
import '../data/models/job_models.dart';
import '../utils/job_copy.dart';

class JobsListView extends GetView<JobsController> {
  const JobsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Supports'),
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
        final jobs = [...controller.jobs]..sort((a, b) {
          final byClient = compareNames(
            a.clientName ?? 'No client',
            b.clientName ?? 'No client',
          );
          if (byClient != 0) return byClient;
          return compareNames(a.title, b.title);
        });
        return RefreshIndicator(
          onRefresh: controller.loadAll,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (err != null) ...[
                _ErrorBox(err),
                const SizedBox(height: 12),
              ],
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text('No jobs yet.'),
                )
              else
                ..._groupedJobTiles(context, jobs),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _groupedJobTiles(BuildContext context, List<JobOut> jobs) {
    final children = <Widget>[];
    String? lastGroup;
    for (final job in jobs) {
      final group = job.clientName ?? 'No client';
      if (group != lastGroup) {
        if (lastGroup != null) {
          children.add(const SizedBox(height: 8));
        }
        lastGroup = group;
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              group,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        );
      }
      children.add(
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(job.title),
            subtitle: Text(
              jobListSubtitle(
                kind: job.kind,
                status: job.status,
                hasSite: job.clientSiteId != null,
                hasBranch: job.branchId != null,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => controller.openDetail(job),
          ),
        ),
      );
    }
    return children;
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
