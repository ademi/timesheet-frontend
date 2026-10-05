import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../data/composer_models.dart';
import '../../../../jobs/data/models/job_models.dart';
import '../roster_composer_controller.dart';

/// Form requirement chips — inherited read-only; overrides editable.
///
/// Preview runs automatically when this step opens (and after edits).
/// Chosen overrides are shown immediately without waiting on a button.
class ComposerFormsSection extends GetView<RosterComposerController> {
  const ComposerFormsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final resolved = controller.resolvedForms.toList(growable: false);
      final overrides = controller.formOverrides.toList(growable: false);
      final loading = controller.formsPreviewLoading.value;
      final err = controller.formsPreviewError.value;
      final addOverrides = [
        for (final o in overrides)
          if (o.action == 'add' &&
              !resolved.any((f) => f.formTemplateId == o.formTemplateId))
            o,
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Forms', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Inherited requirements load automatically. Add or remove overrides only.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (err != null) ...[
            Text(
              err,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
            TextButton(
              onPressed: controller.retryFormsPreview,
              child: const Text('Retry'),
            ),
          ],
          if (resolved.isEmpty && overrides.isEmpty)
            const Text(
              'No form requirements yet.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final form in resolved)
                  _FormChip(
                    form: form,
                    isOverride: form.source == 'override',
                    onRemove:
                        () => controller.removeFormOverride(form.formTemplateId),
                  ),
                for (final o in addOverrides)
                  InputChip(
                    key: Key('form-override-add-${o.formTemplateId}'),
                    label: Text(
                      '${o.name.isEmpty ? o.formTemplateId : o.name} · Override',
                    ),
                    onDeleted:
                        () => controller.removeFormOverride(o.formTemplateId),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
                for (final o in overrides)
                  if (o.action == 'remove')
                    Chip(
                      key: Key('form-override-remove-${o.formTemplateId}'),
                      label: Text(
                        'Removed: ${o.name.isEmpty ? o.formTemplateId : o.name}',
                      ),
                      backgroundColor: AppColors.errorBackground,
                      deleteIcon: const Icon(Icons.undo, size: 18),
                      onDeleted:
                          () => controller.clearFormOverride(o.formTemplateId),
                    ),
              ],
            ),
          const SizedBox(height: 12),
          _AddFormOverrideMenu(controller: controller),
        ],
      );
    });
  }
}

class _FormChip extends StatelessWidget {
  const _FormChip({
    required this.form,
    required this.isOverride,
    required this.onRemove,
  });

  final ResolvedFormPreviewOut form;
  final bool isOverride;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (form.source) {
      'org' => 'Org',
      'client' => 'Client',
      'override' => 'Override',
      _ => form.source,
    };
    return InputChip(
      key: Key('form-chip-${form.formTemplateId}'),
      label: Text(
        '${form.name.isEmpty ? form.formTemplateId : form.name}'
        '${form.isRequired ? '' : ' (optional)'} · $sourceLabel',
      ),
      onDeleted: isOverride || form.source != 'override' ? onRemove : null,
      deleteIcon: const Icon(Icons.close, size: 18),
    );
  }
}

class _AddFormOverrideMenu extends StatelessWidget {
  const _AddFormOverrideMenu({required this.controller});

  final RosterComposerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final resolvedIds = {
        for (final f in controller.resolvedForms) f.formTemplateId,
      };
      final overrideAddIds = {
        for (final o in controller.formOverrides)
          if (o.action == 'add') o.formTemplateId,
      };
      final templates = [
        for (final t in controller.formTemplates)
          if (t.isActive &&
              !resolvedIds.contains(t.id) &&
              !overrideAddIds.contains(t.id))
            t,
      ];
      if (templates.isEmpty) {
        return const Text(
          'No additional form templates available.',
          style: TextStyle(color: AppColors.slate500, fontSize: 12),
        );
      }
      // PopupMenu avoids DropdownButtonFormField retaining a selected value
      // after that template is removed from the items list.
      return PopupMenuButton<FormTemplateOut>(
        key: const Key('composer-add-form-override'),
        onSelected: controller.addFormOverride,
        itemBuilder:
            (context) => [
              for (final t in templates)
                PopupMenuItem(value: t, child: Text(t.name)),
            ],
        child: const InputDecorator(
          decoration: InputDecoration(
            labelText: 'Add form override',
            border: OutlineInputBorder(),
            isDense: true,
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            'Choose a form…',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    });
  }
}
