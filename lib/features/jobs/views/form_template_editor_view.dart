import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/form_template_editor_controller.dart';
import '../data/models/job_models.dart';

class FormTemplateEditorView extends StatefulWidget {
  const FormTemplateEditorView({super.key});

  @override
  State<FormTemplateEditorView> createState() => _FormTemplateEditorViewState();
}

class _FormTemplateEditorViewState extends State<FormTemplateEditorView> {
  late final FormTemplateEditorController c;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<FormTemplateEditorController>()) {
      Get.delete<FormTemplateEditorController>();
    }
    c = Get.put(FormTemplateEditorController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<FormTemplateEditorController>()) {
      Get.delete<FormTemplateEditorController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(c.isEditing ? 'Edit template' : 'Create template'),
      ),
      body: Obx(() {
        final err = c.error.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[
              Container(
                width: double.infinity,
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
            TextField(
              controller: c.nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Template name *',
                hintText: 'e.g. Progress notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                subtitle: const Text(
                  'Inactive templates stay in the catalog but should not be used for new visits.',
                ),
                value: c.isActive.value,
                onChanged: (v) => c.isActive.value = v,
              ),
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fields contractors fill in',
                    style: Get.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: c.isSaving.value ? null : c.addField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add field'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Drag to reorder. Each field needs an id, label, and type.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.fields.length,
              onReorder: c.reorderFields,
              itemBuilder: (context, index) {
                final field = c.fields[index];
                return _FieldCard(
                  key: ObjectKey(field),
                  index: index,
                  field: field,
                  controller: c,
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: c.isSaving.value
                  ? null
                  : () async {
                      final ok = await c.save();
                      if (ok && mounted) Get.back(result: true);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: c.isSaving.value
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(c.isEditing ? 'Save template' : 'Create template'),
            ),
          ],
        );
      }),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({
    super.key,
    required this.index,
    required this.field,
    required this.controller,
  });

  final int index;
  final FormTemplateFieldDraft field;
  final FormTemplateEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.drag_handle, color: AppColors.textMuted),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Field ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove field',
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.removeField(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              controller: field.labelCtrl,
              onChanged: (_) => controller.onLabelChanged(field),
              decoration: const InputDecoration(
                labelText: 'Label *',
                hintText: 'Shown to the contractor',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: field.idCtrl,
              onChanged: (_) => controller.onIdEdited(field),
              decoration: const InputDecoration(
                labelText: 'Field id *',
                hintText: 'Stable key in submissions',
                border: OutlineInputBorder(),
                isDense: true,
                helperText: 'Letters, numbers, underscores; must be unique',
              ),
            ),
            const SizedBox(height: 8),
            Obx(
              () => DropdownButtonFormField<String>(
                value: field.type.value,
                items: [
                  for (final t in formTemplateFieldTypes)
                    DropdownMenuItem(
                      value: t,
                      child: Text(formTemplateFieldTypeLabel(t)),
                    ),
                ],
                onChanged: controller.isSaving.value
                    ? null
                    : (v) {
                        if (v != null) field.type.value = v;
                      },
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Obx(() {
              if (field.type.value != 'file') {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: field.acceptCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Accepted files (optional)',
                    hintText: 'e.g. image/*,.pdf',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText: 'Comma-separated MIME types or extensions',
                  ),
                ),
              );
            }),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Required'),
                value: field.required.value,
                onChanged: controller.isSaving.value
                    ? null
                    : (v) => field.required.value = v,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
