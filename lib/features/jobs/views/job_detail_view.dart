import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/jobs_controller.dart';
import '../data/models/job_models.dart';
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
            if (err != null) ...[_ErrorBox(err), const SizedBox(height: 12)],
            Text(
              '${job.kind} · ${job.status}',
              style: Get.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Location: ${job.clientSiteId != null ? 'site ${job.clientSiteId}' : 'branch ${job.branchId}'}',
            ),
            Text('Geofence: ${job.geofenceMode} / ${job.geofenceRadiusM}m'),
            if (controller.canManage && job.isOpen) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed:
                        controller.isSaving.value
                            ? null
                            : () => controller.setStatus('closed'),
                    child: const Text('Close'),
                  ),
                  OutlinedButton(
                    onPressed:
                        controller.isSaving.value
                            ? null
                            : () => controller.setStatus('cancelled'),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            Text('Form catalog', style: Get.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Templates used on visits for this job. Attach templates here, '
              'then select them when adding recurrence rules or creating '
              'manual visits.',
              style: TextStyle(fontSize: 12),
            ),
            if (controller.formCatalog.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final c in controller.formCatalog)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    c.isActive ? Icons.check_circle : Icons.pause_circle,
                    color: c.isActive ? AppColors.primary : AppColors.textMuted,
                    size: 20,
                  ),
                  title: Text(c.name),
                  subtitle: Text(
                    '${c.isActive ? 'active' : 'inactive'} · '
                    '${c.clientId == null ? 'tenant-wide' : 'client'}',
                  ),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No templates attached yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            const SizedBox(height: 12),
            if (controller.formTemplates.isEmpty)
              const Text('No templates yet.'),
            for (final t in controller.formTemplates)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.name),
                subtitle: Text(
                  '${t.isActive ? 'active' : 'inactive'} · '
                  '${t.clientId == null ? 'tenant-wide' : 'client'}'
                  '${controller.isTemplateAttached(t.id) ? ' · attached' : ''}',
                  style: TextStyle(
                    color:
                        controller.isTemplateAttached(t.id)
                            ? AppColors.primary
                            : null,
                  ),
                ),
                trailing:
                    controller.canManage
                        ? TextButton(
                          onPressed:
                              controller.isSaving.value ||
                                      controller.isTemplateAttached(t.id)
                                  ? null
                                  : () => controller.attachFormTemplate(t.id),
                          child: Text(
                            controller.isTemplateAttached(t.id)
                                ? 'Attached'
                                : 'Attach',
                          ),
                        )
                        : null,
              ),
            if (controller.canManage || controller.canManageForms)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed:
                      controller.isSaving.value
                          ? null
                          : controller.openFormTemplatesAndRefresh,
                  child: Text(
                    controller.formTemplates.isEmpty
                        ? 'Create form template'
                        : 'Manage form templates',
                  ),
                ),
              ),
            const Divider(height: 32),
            Text('Recurrence', style: Get.textTheme.titleMedium),
            if (!job.isStanding)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Recurrence requires a standing job.'),
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
              Row(
                children: [
                  const Text('Generate with partial'),
                  Switch(
                    value: controller.generatePartial.value,
                    onChanged: (v) => controller.generatePartial.value = v,
                  ),
                ],
              ),
              if (controller.lastGenerate.value != null) ...[
                const SizedBox(height: 8),
                _GenerateResult(controller.lastGenerate.value!),
              ],
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
                          '${rule.isActive ? 'active' : 'inactive'} · '
                          'contractor ${rule.contractorId}',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (controller.canManage)
                              OutlinedButton(
                                onPressed:
                                    controller.isSaving.value
                                        ? null
                                        : () =>
                                            controller.toggleRuleActive(rule),
                                child: Text(
                                  rule.isActive ? 'Deactivate' : 'Activate',
                                ),
                              ),
                            if (controller.canManage)
                              ElevatedButton(
                                onPressed:
                                    controller.isSaving.value
                                        ? null
                                        : () =>
                                            controller.generateForRule(rule),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                ),
                                child: const Text('Generate (14d)'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            if (controller.canManageVisits) ...[
              const Divider(height: 32),
              Text('Manual visit', style: Get.textTheme.titleMedium),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: controller.selectedContractorId.value,
                items: [
                  for (final e in controller.assignableEngagements)
                    DropdownMenuItem(
                      value: e.contractorId,
                      child: Text(e.contractorName ?? e.contractorId),
                    ),
                ],
                onChanged: (v) => controller.selectedContractorId.value = v,
                decoration: const InputDecoration(
                  labelText: 'Contractor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.manualTaskCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Task titles (one per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : controller.createManualVisit,
                child: const Text('Create manual visit'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    () => Get.toNamed(
                      AppRoutes.staffVisits,
                      arguments: {'job_id': job.id},
                    ),
                child: const Text('Open visits for this job'),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _GenerateResult extends StatelessWidget {
  const _GenerateResult(this.result);
  final GenerateVisitsResponse result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Created ${result.createdVisitIds.length}; skipped ${result.skipped.length}'
        '${result.skipped.isEmpty ? '' : ': ${result.skipped.map((s) => s.detail).join('; ')}'}',
      ),
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
