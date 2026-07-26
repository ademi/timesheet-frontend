import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/jobs_controller.dart';

class FormTemplatesView extends GetView<JobsController> {
  const FormTemplatesView({super.key});

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
                child: Text(err, style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 12),
            ],
            if (controller.canManageForms) ...[
              TextField(
                controller: controller.templateNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'New template name *',
                  border: OutlineInputBorder(),
                  helperText: 'Creates a simple Notes (textarea) schema',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: controller.isSaving.value
                    ? null
                    : controller.createFormTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                ),
                child: const Text('Create template'),
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
                    '${t.isActive ? 'active' : 'inactive'} · ${t.id}',
                  ),
                  trailing: controller.canManageForms
                      ? IconButton(
                          tooltip: 'Delete',
                          onPressed: controller.isSaving.value
                              ? null
                              : () => controller.deleteFormTemplate(t.id),
                          icon: const Icon(Icons.delete_outline),
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
