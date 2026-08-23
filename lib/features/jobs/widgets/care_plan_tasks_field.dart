import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/job_models.dart';
import '../utils/task_title_presets.dart';

/// Care plan / shift task title editor (one title per line).
class CarePlanTasksField extends StatelessWidget {
  const CarePlanTasksField({
    super.key,
    required this.taskTitlesCtrl,
    required this.otherTitleCtrl,
    required this.showOtherTitleField,
    required this.onPresetSelected,
    required this.onAppendOtherTitle,
    this.sectionTitle = 'Care plan tasks',
    this.helperText =
        'Optional task titles copied onto generated or booked visits.',
  });

  final TextEditingController taskTitlesCtrl;
  final TextEditingController otherTitleCtrl;
  final RxBool showOtherTitleField;
  final ValueChanged<String?> onPresetSelected;
  final VoidCallback onAppendOtherTitle;
  final String sectionTitle;
  final String? helperText;

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
        const SizedBox(height: 8),
        TextField(
          controller: taskTitlesCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Task titles (one per line)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

List<TaskTemplateItem> taskTemplateFromTitles(String text) {
  final titles = parseTaskTitles(text);
  return [
    for (var i = 0; i < titles.length; i++)
      TaskTemplateItem(title: titles[i], sortOrder: i),
  ];
}
