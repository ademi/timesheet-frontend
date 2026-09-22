import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/jobs_controller.dart';
import '../data/models/job_models.dart';

/// Job-scoped screen to attach catalog templates and open create/edit.
class JobManageTemplatesView extends StatefulWidget {
  const JobManageTemplatesView({super.key});

  @override
  State<JobManageTemplatesView> createState() => _JobManageTemplatesViewState();
}

class _JobManageTemplatesViewState extends State<JobManageTemplatesView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<JobsController>();
    c.hydrateSelectedFromArgs();
    c.clearPendingAttach();
    if (c.formCatalog.isEmpty && c.selected.value != null) {
      c.refreshFormCatalog();
    }
  }

  String _fieldSummary(FormTemplateOut t) {
    final raw = t.schemaJson['fields'];
    final count = raw is List ? raw.length : 0;
    return '$count field${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<JobsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.selected.value != null
                ? 'Manage templates'
                : 'Form templates',
          ),
        ),
      ),
      body: Obx(() {
        final job = controller.selected.value;
        final err = controller.errorMessage.value;
        final attaching = controller.isPending(
          JobsController.attachCatalogPendingKey,
        );
        final pendingCount = controller.pendingAttachIds.length;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (err != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        err,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (job != null) ...[
                    Text(
                      'Templates for “${job.title}”',
                      style: Get.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Attach templates to this job, then select them when adding '
                      'recurrence rules or creating manual visits.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Attached to this job',
                      style: Get.textTheme.titleSmall,
                    ),
                    if (controller.formCatalog.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 8),
                        child: Text(
                          'No templates attached yet.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else
                      for (final c in controller.formCatalog)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                            c.isActive
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            color:
                                c.isActive
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                            size: 20,
                          ),
                          title: Text(c.name),
                          subtitle: Text(
                            '${c.isActive ? 'active' : 'inactive'} · '
                            '${c.clientId == null ? 'tenant-wide' : 'client'}',
                          ),
                        ),
                    const Divider(height: 32),
                  ],
                  if (!controller.canManageForms)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'You can view templates but need clients.manage to create or edit fields.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  if (controller.canManageForms) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed:
                            controller.isSaving.value
                                ? null
                                : () => controller.openFormTemplateEditor(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create template'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cta,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All templates',
                          style: Get.textTheme.titleSmall,
                        ),
                      ),
                      if (controller.canManage && pendingCount > 0)
                        TextButton(
                          onPressed:
                              attaching
                                  ? null
                                  : controller.attachSelectedFormTemplates,
                          child: AsyncButtonChild(
                            isLoading: attaching,
                            child: Text('Attach selected ($pendingCount)'),
                          ),
                        ),
                    ],
                  ),
                  if (controller.canManage &&
                      controller.formTemplates.any(
                        (t) => !controller.isTemplateAttached(t.id),
                      ))
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Select one or more templates, then Attach selected.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (controller.formTemplates.isEmpty)
                    const Text('No form templates yet.'),
                  for (final t in controller.formTemplates)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading:
                            controller.canManage &&
                                    !controller.isTemplateAttached(t.id)
                                ? Checkbox(
                                  value: controller.pendingAttachIds.contains(
                                    t.id,
                                  ),
                                  onChanged:
                                      attaching
                                          ? null
                                          : (_) => controller.togglePendingAttach(
                                            t.id,
                                          ),
                                )
                                : Icon(
                                  controller.isTemplateAttached(t.id)
                                      ? Icons.check_circle
                                      : Icons.description_outlined,
                                  color:
                                      controller.isTemplateAttached(t.id)
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                  size: 22,
                                ),
                        title: Text(t.name),
                        subtitle: Text(
                          '${t.isActive ? 'active' : 'inactive'} · '
                          '${t.clientId == null ? 'tenant-wide' : 'client'} · '
                          '${_fieldSummary(t)}'
                          '${controller.isTemplateAttached(t.id) ? ' · attached' : ''}',
                          style: TextStyle(
                            color:
                                controller.isTemplateAttached(t.id)
                                    ? AppColors.primary
                                    : null,
                          ),
                        ),
                        isThreeLine: true,
                        onTap:
                            controller.canManage &&
                                    !controller.isTemplateAttached(t.id) &&
                                    !attaching
                                ? () => controller.togglePendingAttach(t.id)
                                : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (controller.canManageForms) ...[
                              IconButton(
                                tooltip: 'Edit fields',
                                onPressed:
                                    controller.isSaving.value
                                        ? null
                                        : () =>
                                            controller.openFormTemplateEditor(
                                              existing: t,
                                            ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              AsyncIconButton(
                                tooltip: 'Delete',
                                onPressed:
                                    () => controller.deleteFormTemplate(t.id),
                                isLoading: controller.isSaving.value,
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
