import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/widgets/ndis_support_item_picker.dart';
import '../../../../jobs/widgets/visit_instructions_field.dart';
import '../../../data/composer_models.dart';
import '../roster_composer_controller.dart';

/// Support step — anchor NDIS item + worker task checklist (A8) + segments.
class ComposerSupportSection extends GetView<RosterComposerController> {
  const ComposerSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final code = controller.draft.value.supportItemCode;
      final name = controller.supportItemName.value;
      final visitIds = controller.visitIdsWithSegments;
      final taskCount = controller.draft.value.taskTemplate.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Support', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Anchor NDIS item for publish, then list tasks workers should complete.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          NdisSupportItemPicker(
            key: const Key('composer-support-item'),
            supportItemCode: code,
            supportItemName: name.isEmpty ? null : name,
            onChanged: ({required supportItemCode, required supportItemName}) {
              controller.setSupportItem(
                code: supportItemCode,
                name: supportItemName,
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Tasks', style: Get.textTheme.titleSmall),
              ),
              Text(
                taskCount == 0 ? 'None yet' : '$taskCount listed',
                key: const Key('composer-tasks-count'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ComposerTasksField(controller: controller),
          if (visitIds.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Segments', style: Get.textTheme.titleSmall),
            const SizedBox(height: 4),
            const Text(
              'Edit planned segments after a worker is assigned.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (controller.segmentsError.value != null)
              Text(
                controller.segmentsError.value!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            for (final visitId in visitIds) ...[
              _VisitSegmentsEditor(
                key: Key('segments-visit-$visitId'),
                visitId: visitId,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      );
    });
  }
}

/// One line → one task template item. Remounts with the Support step key.
class _ComposerTasksField extends StatefulWidget {
  const _ComposerTasksField({required this.controller});

  final RosterComposerController controller;

  @override
  State<_ComposerTasksField> createState() => _ComposerTasksFieldState();
}

class _ComposerTasksFieldState extends State<_ComposerTasksField> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(
      text: [
        for (final t in widget.controller.draft.value.taskTemplate) t.title,
      ].join('\n'),
    );
    _text.addListener(_onText);
  }

  @override
  void dispose() {
    _text.removeListener(_onText);
    _text.dispose();
    super.dispose();
  }

  void _onText() {
    widget.controller.setTaskTitles(_text.text.split('\n'));
  }

  @override
  Widget build(BuildContext context) {
    return VisitInstructionsField(
      key: const Key('composer-tasks-field'),
      controller: _text,
      sectionTitle: null,
      labelText: 'Tasks for workers (optional)',
      helperText:
          'One task per line. Saved on the draft and stamped onto visits when workers are assigned.',
      maxLines: 6,
    );
  }
}

class _VisitSegmentsEditor extends StatefulWidget {
  const _VisitSegmentsEditor({super.key, required this.visitId});

  final String visitId;

  @override
  State<_VisitSegmentsEditor> createState() => _VisitSegmentsEditorState();
}

class _VisitSegmentsEditorState extends State<_VisitSegmentsEditor> {
  late String? _code;
  late String? _name;
  final controller = Get.find<RosterComposerController>();

  @override
  void initState() {
    super.initState();
    final segments = controller.segmentsByVisit[widget.visitId] ?? const [];
    _code =
        segments.isNotEmpty
            ? segments.first.anchorSupportItemCode
            : controller.draft.value.supportItemCode;
    _name =
        segments.isNotEmpty
            ? segments.first.anchorSupportItemName
            : controller.supportItemName.value;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final start = controller.draft.value.scheduledStart;
      final end = controller.draft.value.scheduledEnd;
      final participants = controller.shiftParticipants;
      final defaultSp = participants.isNotEmpty ? participants.first.id : '';
      final saving = controller.segmentsSaving.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Visit ${widget.visitId.length > 8 ? widget.visitId.substring(0, 8) : widget.visitId}…',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 8),
          NdisSupportItemPicker(
            key: Key('segments-item-${widget.visitId}'),
            supportItemCode: _code,
            supportItemName: _name,
            labelText: 'Segment anchor item',
            onChanged: ({required supportItemCode, required supportItemName}) {
              setState(() {
                _code = supportItemCode;
                _name = supportItemName;
              });
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('segments-save-${widget.visitId}'),
              onPressed:
                  saving ||
                          start == null ||
                          end == null ||
                          defaultSp.isEmpty ||
                          (_code?.trim().isEmpty ?? true)
                      ? null
                      : () async {
                        await controller.saveVisitSegments(widget.visitId, [
                          SupportSegmentIn(
                            shiftParticipantId: defaultSp,
                            anchorSupportItemCode: _code!.trim(),
                            startAt: start.toUtc(),
                            endAt: end.toUtc(),
                          ),
                        ]);
                      },
              child: const Text('Save segments'),
            ),
          ),
        ],
      );
    });
  }
}
