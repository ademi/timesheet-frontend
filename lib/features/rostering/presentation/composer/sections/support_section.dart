import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/widgets/keyboard_time_field.dart';
import '../../../../../shared/widgets/ndis_support_item_picker.dart';
import '../../../../jobs/widgets/visit_instructions_field.dart';
import '../../../../shifts/data/models/shift_models.dart';
import '../../../data/composer_models.dart';
import '../../../domain/support_segment_editor.dart';
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
              'Add timed support items after a worker is assigned. '
              'Every active participant needs at least one segment.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (controller.segmentsError.value != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  controller.segmentsError.value!,
                  key: const Key('composer-segments-error'),
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
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
  final controller = Get.find<RosterComposerController>();
  late List<SupportSegmentRowDraft> _rows;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _rows = _hydrateRows();
  }

  List<ShiftParticipantOut> get _activeParticipants => [
    for (final p in controller.shiftParticipants)
      if (p.status == 'active') p,
  ];

  List<SupportSegmentRowDraft> _hydrateRows() {
    final existing = controller.segmentsByVisit[widget.visitId] ?? const [];
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    final participants = _activeParticipants;
    final defaultCode = controller.draft.value.supportItemCode ?? '';
    final defaultName = controller.supportItemName.value;

    if (existing.isNotEmpty) {
      return [
        for (final s in existing)
          SupportSegmentRowDraft(
            shiftParticipantId: s.shiftParticipantId,
            anchorSupportItemCode: s.anchorSupportItemCode,
            anchorSupportItemName: s.anchorSupportItemName,
            kind: s.kind,
            startAt: s.startAt.toLocal(),
            endAt: s.endAt.toLocal(),
          ),
      ];
    }

    if (start == null || end == null || participants.isEmpty) {
      return [];
    }

    // Mode A seed: one full-window direct segment per active participant.
    return [
      for (final p in participants)
        SupportSegmentRowDraft(
          shiftParticipantId: p.id,
          anchorSupportItemCode: defaultCode,
          anchorSupportItemName: defaultName.isEmpty ? null : defaultName,
          startAt: start,
          endAt: end,
        ),
    ];
  }

  void _addRow() {
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    if (start == null || end == null) return;
    final participants = _activeParticipants;
    final defaultSp =
        participants.isNotEmpty ? participants.first.id : '';
    final defaultCode = controller.draft.value.supportItemCode ?? '';
    final defaultName = controller.supportItemName.value;
    setState(() {
      _localError = null;
      _rows = [
        ..._rows,
        SupportSegmentRowDraft(
          shiftParticipantId: defaultSp,
          anchorSupportItemCode: defaultCode,
          anchorSupportItemName: defaultName.isEmpty ? null : defaultName,
          startAt: start,
          endAt: end,
        ),
      ];
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) return;
    setState(() {
      _localError = null;
      _rows = [
        for (var i = 0; i < _rows.length; i++)
          if (i != index) _rows[i],
      ];
    });
  }

  Future<void> _save() async {
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    if (start == null || end == null) {
      setState(() => _localError = 'Set the visit schedule before saving segments.');
      return;
    }

    final activeIds = {for (final p in _activeParticipants) p.id};
    final validation = validateSupportSegmentRows(
      rows: _rows,
      visitStart: start,
      visitEnd: end,
      activeShiftParticipantIds: activeIds,
    );
    if (validation != null) {
      setState(() => _localError = validation);
      controller.segmentsError.value = validation;
      return;
    }

    setState(() => _localError = null);
    await controller.saveVisitSegments(widget.visitId, [
      for (var i = 0; i < _rows.length; i++)
        SupportSegmentIn(
          shiftParticipantId: _rows[i].shiftParticipantId,
          anchorSupportItemCode: _rows[i].anchorSupportItemCode.trim(),
          kind: _rows[i].kind,
          startAt: _rows[i].startAt.toUtc(),
          endAt: _rows[i].endAt.toUtc(),
          sortOrder: i,
        ),
    ]);
    if (controller.segmentsError.value == null && mounted) {
      setState(() {
        _rows = _hydrateRows();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saving = controller.segmentsSaving.value;
      // Touch segments map so hydrate after save refreshes Obx consumers.
      controller.segmentsByVisit[widget.visitId];
      final participants = _activeParticipants;
      final shortId =
          widget.visitId.length > 8
              ? '${widget.visitId.substring(0, 8)}…'
              : widget.visitId;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Visit $shortId',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++) ...[
            _SegmentRowCard(
              key: Key('segment-row-${widget.visitId}-$i'),
              index: i,
              row: _rows[i],
              participants: participants,
              canRemove: _rows.length > 1 && !saving,
              onChanged: () => setState(() => _localError = null),
              onRemove: () => _removeRow(i),
            ),
            const SizedBox(height: 12),
          ],
          if (_localError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _localError!,
                key: Key('segments-local-error-${widget.visitId}'),
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                key: Key('segments-add-${widget.visitId}'),
                onPressed: saving ? null : _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add segment'),
              ),
              const Spacer(),
              TextButton(
                key: Key('segments-save-${widget.visitId}'),
                onPressed: saving || _rows.isEmpty ? null : _save,
                child:
                    saving
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save segments'),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _SegmentRowCard extends StatelessWidget {
  const _SegmentRowCard({
    super.key,
    required this.index,
    required this.row,
    required this.participants,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final SupportSegmentRowDraft row;
  final List<ShiftParticipantOut> participants;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final participantIds = {for (final p in participants) p.id};
    final selectedSp =
        participantIds.contains(row.shiftParticipantId)
            ? row.shiftParticipantId
            : (participants.isNotEmpty ? participants.first.id : null);
    final kind =
        kSupportSegmentKinds.contains(row.kind) ? row.kind : 'direct';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Segment ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  key: Key('segment-remove-$index'),
                  tooltip: 'Remove segment',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (participants.length > 1) ...[
            DropdownButtonFormField<String>(
              key: Key('segment-participant-$index'),
              value: selectedSp,
              decoration: const InputDecoration(
                labelText: 'Participant',
                isDense: true,
              ),
              items: [
                for (final p in participants)
                  DropdownMenuItem(
                    value: p.id,
                    child: Text(
                      p.participantName?.trim().isNotEmpty == true
                          ? p.participantName!
                          : 'Participant',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) {
                if (v == null) return;
                row.shiftParticipantId = v;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
          ],
          NdisSupportItemPicker(
            key: Key('segment-item-$index'),
            supportItemCode:
                row.anchorSupportItemCode.isEmpty
                    ? null
                    : row.anchorSupportItemCode,
            supportItemName: row.anchorSupportItemName,
            labelText: 'Support item',
            onChanged: ({required supportItemCode, required supportItemName}) {
              row.anchorSupportItemCode = supportItemCode?.trim() ?? '';
              row.anchorSupportItemName = supportItemName;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: Key('segment-kind-$index'),
            value: kind,
            decoration: const InputDecoration(
              labelText: 'Kind',
              isDense: true,
            ),
            items: [
              for (final k in kSupportSegmentKinds)
                DropdownMenuItem(
                  value: k,
                  child: Text(supportSegmentKindLabel(k)),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              row.kind = v;
              onChanged();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: KeyboardTimeField(
                  key: Key('segment-start-$index'),
                  label: 'Start',
                  value: TimeOfDay(
                    hour: row.startAt.hour,
                    minute: row.startAt.minute,
                  ),
                  onChanged: (t) {
                    row.startAt = DateTime(
                      row.startAt.year,
                      row.startAt.month,
                      row.startAt.day,
                      t.hour,
                      t.minute,
                    );
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KeyboardTimeField(
                  key: Key('segment-end-$index'),
                  label: 'End',
                  value: TimeOfDay(
                    hour: row.endAt.hour,
                    minute: row.endAt.minute,
                  ),
                  onChanged: (t) {
                    row.endAt = DateTime(
                      row.endAt.year,
                      row.endAt.month,
                      row.endAt.day,
                      t.hour,
                      t.minute,
                    );
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
