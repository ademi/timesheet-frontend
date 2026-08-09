import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/jobs_controller.dart';
import '../data/models/job_models.dart';

/// Job-scoped screen to attach catalog templates and create/edit/delete them.
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
    if (c.formCatalog.isEmpty && c.selected.value != null) {
      c.refreshFormCatalog();
    }
  }

  Future<void> _editTemplate(FormTemplateOut template) async {
    final controller = Get.find<JobsController>();
    final nameCtrl = TextEditingController(text: template.name);
    var isActive = template.isActive;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Edit template'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Template name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setLocal(() => isActive = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    final name = nameCtrl.text;
    nameCtrl.dispose();
    if (saved != true) return;
    await controller.updateFormTemplate(
      id: template.id,
      name: name,
      isActive: isActive,
    );
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
        return ListView(
          padding: const EdgeInsets.all(16),
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
              Text('Attached to this job', style: Get.textTheme.titleSmall),
              if (controller.formCatalog.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    'No templates attached yet.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                )
              else
                for (final c in controller.formCatalog)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      c.isActive ? Icons.check_circle : Icons.pause_circle,
                      color:
                          c.isActive ? AppColors.primary : AppColors.textMuted,
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
                  'You can view templates but need clients.manage to create or edit.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            if (controller.canManageForms) ...[
              Text('Add template', style: Get.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: controller.templateNameCtrl,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => controller.createFormTemplate(),
                decoration: const InputDecoration(
                  labelText: 'New template name *',
                  hintText: 'e.g. Progress notes',
                  border: OutlineInputBorder(),
                  helperText:
                      'Creates a tenant-wide Notes (textarea) form schema',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed:
                    controller.isSaving.value
                        ? null
                        : controller.createFormTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                ),
                child:
                    controller.isSaving.value
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Create template'),
              ),
              const Divider(height: 32),
            ],
            Text('All templates', style: Get.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (controller.formTemplates.isEmpty)
              const Text('No form templates yet.'),
            for (final t in controller.formTemplates)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (controller.canManage)
                        TextButton(
                          onPressed:
                              controller.isSaving.value ||
                                      controller.isTemplateAttached(t.id)
                                  ? null
                                  : () => controller.attachFormTemplate(t.id),
                          child: AsyncButtonChild(
                            isLoading:
                                controller.isSaving.value &&
                                !controller.isTemplateAttached(t.id),
                            child: Text(
                              controller.isTemplateAttached(t.id)
                                  ? 'Attached'
                                  : 'Attach',
                            ),
                          ),
                        ),
                      if (controller.canManageForms) ...[
                        IconButton(
                          tooltip: 'Edit',
                          onPressed:
                              controller.isSaving.value
                                  ? null
                                  : () => _editTemplate(t),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        AsyncIconButton(
                          tooltip: 'Delete',
                          onPressed: () => controller.deleteFormTemplate(t.id),
                          isLoading: controller.isSaving.value,
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
