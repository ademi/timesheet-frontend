import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/jobs_controller.dart';
import '../data/models/job_models.dart';

class FormTemplatesView extends GetView<JobsController> {
  const FormTemplatesView({super.key});

  String _fieldSummary(FormTemplateOut t) {
    final raw = t.schemaJson['fields'];
    final count = raw is List ? raw.length : 0;
    return '$count field${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Form templates')),
      body: Obx(() {
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
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.openFormTemplateEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create template'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                ),
              ),
              const Divider(height: 32),
            ],
            if (controller.formTemplates.isEmpty)
              const Text('No form templates yet.'),
            for (final t in controller.formTemplates)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    '${t.isActive ? 'active' : 'inactive'}'
                    '${t.clientId == null ? ' · tenant-wide' : ' · client'} · '
                    '${_fieldSummary(t)}',
                  ),
                  trailing: controller.canManageForms
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit fields',
                              onPressed: controller.isSaving.value
                                  ? null
                                  : () => controller.openFormTemplateEditor(
                                        existing: t,
                                      ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            AsyncIconButton(
                              tooltip: 'Delete',
                              onPressed: () =>
                                  controller.deleteFormTemplate(t.id),
                              isLoading: controller.isSaving.value,
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
          ],
        );
      }),
    );
  }
}
