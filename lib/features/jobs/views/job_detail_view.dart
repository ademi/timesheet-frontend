import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../controllers/jobs_controller.dart';
import '../utils/job_copy.dart';
import '../utils/recurrence_label.dart';

class JobDetailView extends StatefulWidget {
  const JobDetailView({super.key});

  @override
  State<JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends State<JobDetailView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<JobsController>();
    c.ensureDetailLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<JobsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() => Text(controller.selected.value?.title ?? 'Job')),
      ),
      body: Obx(() {
        final job = controller.selected.value;
        if (job == null) {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(
            child: Text(controller.errorMessage.value ?? 'Job not loaded.'),
          );
        }
        final err = controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            if (err != null) ...[_ErrorBox(err), const SizedBox(height: 12)],
            Text(
              '${kindLabel(job.kind)} · ${jobStatusLabel(job.status)}',
              style: Get.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Location: ${job.locationLabel ?? job.clientSiteName ?? job.branchName ?? 'Location not set'}',
            ),
            Text('Geofence: ${job.geofenceMode} / ${job.geofenceRadiusM}m'),
            const SizedBox(height: 16),
            Text('Default NDIS support item', style: Get.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (controller.canManage && job.isOpen)
              NdisSupportItemPicker(
                supportItemCode: controller.editingSupportItemCode.value,
                supportItemName: controller.editingSupportItemName.value,
                enabled: !controller.isSaving.value,
                labelText: 'NDIS support item',
                onChanged: ({
                  required String? supportItemCode,
                  required String? supportItemName,
                }) {
                  controller.updateJobSupportItem(
                    supportItemCode: supportItemCode,
                    supportItemName: supportItemName,
                  );
                },
              )
            else if (job.supportItemCode != null &&
                job.supportItemName != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.supportItemName!),
                  Text(
                    job.supportItemCode!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'None set.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            const SizedBox(height: 4),
            const Text(
              'Updates propagate to visits that still use the previous default.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (controller.canManage && job.isOpen) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AsyncOutlinedButton(
                    onPressed: () => controller.setStatus('closed'),
                    isLoading: controller.isSaving.value,
                    child: const Text('Close'),
                  ),
                  AsyncOutlinedButton(
                    onPressed: () => controller.setStatus('cancelled'),
                    isLoading: controller.isSaving.value,
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: controller.isSaving.value
                        ? null
                        : () => Get.toNamed(
                              AppRoutes.staffVisits,
                              arguments: <String, dynamic>{
                                'job_id': job.id,
                                'create': true,
                              },
                            ),
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('Book one session'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                    ),
                  ),
                  if (controller.canFillHorizon)
                    AsyncOutlinedButton(
                      onPressed: controller.fillNext14Days,
                      isLoading: controller.isFillingHorizon.value,
                      child: const Text('Fill next 14 days'),
                    ),
                ],
              ),
            ],
            const Divider(height: 32),
            Text('Templates', style: Get.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              controller.formCatalog.isEmpty
                  ? 'No templates attached to this job yet.'
                  : '${controller.formCatalog.length} template'
                      '${controller.formCatalog.length == 1 ? '' : 's'} '
                      'attached to this job.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : controller.openManageTemplatesAndRefresh,
                icon: const Icon(Icons.description_outlined),
                label: const Text('Manage templates'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
              ),
            ),
            const Divider(height: 32),
            Text('Patterns', style: Get.textTheme.titleMedium),
            if (!job.isStanding)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Patterns need ongoing support.'),
              )
            else ...[
              const SizedBox(height: 8),
              if (controller.canManage)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed:
                        controller.isSaving.value
                            ? null
                            : () =>
                                Get.toNamed(AppRoutes.staffRecurrenceRuleForm),
                    icon: const Icon(Icons.add),
                    label: const Text('Add recurrence rule'),
                  ),
                ),
              const SizedBox(height: 12),
              for (final rule in controller.rules)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recurrenceLabel(rule),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${rule.isActive ? 'Active' : 'Paused'} · '
                          '${rule.contractorName ?? 'Unfilled'}',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (controller.canManage)
                              AsyncOutlinedButton(
                                onPressed: () =>
                                    controller.toggleRuleActive(rule),
                                isLoading: controller.isSaving.value,
                                child: Text(
                                  rule.isActive ? 'Deactivate' : 'Activate',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
              ),
            ),
          ],
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
