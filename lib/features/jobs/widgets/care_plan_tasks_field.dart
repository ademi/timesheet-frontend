import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/ndis_support_item_picker.dart';
import '../../billing/data/ndis_catalogue_filter_prefs.dart';
import '../../billing/data/repositories/ndis_catalogue_repository.dart';
import '../data/models/job_models.dart';
import '../utils/task_title_presets.dart';

/// Care-plan / shift tasks with [TaskTemplateItem] as the only source of truth.
///
/// Primary add path is the NDIS catalogue picker; presets and custom titles
/// append items with a null support item code.
class CarePlanTasksField extends StatelessWidget {
  const CarePlanTasksField({
    super.key,
    required this.tasks,
    required this.otherTitleCtrl,
    required this.showOtherTitleField,
    required this.onPresetSelected,
    required this.onAppendOtherTitle,
    required this.onRemoveTask,
    required this.onCataloguePicked,
    this.catalogueRepository,
    this.filterPrefs,
    this.sectionTitle = 'Care plan tasks',
    this.helperText =
        'Optional tasks copied onto generated or booked visits.',
  });

  final RxList<TaskTemplateItem> tasks;
  final TextEditingController otherTitleCtrl;
  final RxBool showOtherTitleField;
  final ValueChanged<String?> onPresetSelected;
  final VoidCallback onAppendOtherTitle;
  final ValueChanged<int> onRemoveTask;
  final void Function({required String code, required String name})
      onCataloguePicked;
  final NdisCatalogueRepository? catalogueRepository;
  final NdisCatalogueFilterPrefs? filterPrefs;
  final String sectionTitle;
  final String? helperText;

  Future<void> _openCataloguePicker(BuildContext context) async {
    final picked = await showDialog<({String code, String name})>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('catalogue-task-picker-dialog'),
          title: const Text('Add from catalogue'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: NdisSupportItemPicker(
                labelText: 'Support item',
                searchHintText: 'Search catalogue by name or item number',
                repository: catalogueRepository,
                filterPrefs: filterPrefs,
                debounceDuration: Duration.zero,
                onChanged: ({
                  required String? supportItemCode,
                  required String? supportItemName,
                }) {
                  final code = supportItemCode?.trim();
                  final name = supportItemName?.trim();
                  if (code == null ||
                      code.isEmpty ||
                      name == null ||
                      name.isEmpty) {
                    return;
                  }
                  Navigator.of(dialogContext).pop((code: code, name: name));
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (picked == null) return;
    onCataloguePicked(code: picked.code, name: picked.name);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(sectionTitle, style: Get.textTheme.titleSmall),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: const Key('add-from-catalogue'),
            onPressed: () => _openCataloguePicker(context),
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Add from catalogue'),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: null,
          items: [
            for (final preset in taskTitlePresets)
              DropdownMenuItem(value: preset, child: Text(preset)),
            const DropdownMenuItem(
              value: taskTitlePresetOther,
              child: Text(taskTitlePresetOther),
            ),
          ],
          onChanged: onPresetSelected,
          decoration: const InputDecoration(
            labelText: 'Add preset task',
            border: OutlineInputBorder(),
          ),
        ),
        Obx(() {
          if (!showOtherTitleField.value) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: otherTitleCtrl,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      labelText: 'Custom task title',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onAppendOtherTitle(),
                  ),
                ),
                IconButton(
                  onPressed: onAppendOtherTitle,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add task',
                ),
              ],
            ),
          );
        }),
        Obx(() {
          if (tasks.isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              const SizedBox(height: 8),
              for (var i = 0; i < tasks.length; i++)
                _TaskRow(
                  index: i,
                  task: tasks[i],
                  onRemove: () => onRemoveTask(i),
                ),
            ],
          );
        }),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.index,
    required this.task,
    required this.onRemove,
  });

  final int index;
  final TaskTemplateItem task;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final code = task.supportItemCode?.trim();
    return Dismissible(
      key: ValueKey('care-plan-task-$index-${task.title}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: AppColors.errorBackground,
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(task.title),
        subtitle: (code != null && code.isNotEmpty)
            ? Text(
                code,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              )
            : null,
        trailing: IconButton(
          key: ValueKey('remove-care-plan-task-$index'),
          tooltip: 'Remove task',
          onPressed: onRemove,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}
