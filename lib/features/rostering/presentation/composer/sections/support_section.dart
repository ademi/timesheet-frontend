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
      final showLive = visitIds.isNotEmpty;
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
          const SizedBox(height: 24),
          Text('Segments', style: Get.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            showLive
                ? 'Add timed support items after a worker is assigned. '
                    'Every active participant needs at least one segment.'
                : kDraftSegmentsIntroCopy,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
          if (showLive)
            for (final visitId in visitIds) ...[
              _VisitSegmentsEditor(
                key: Key(
                  'segments-visit-$visitId-'
                  '${controller.segmentsByVisit[visitId]?.length ?? 0}',
                ),
                visitId: visitId,
              ),
              const SizedBox(height: 12),
            ]
          else
            const _DraftSegmentsEditor(key: Key('segments-draft-template')),
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

/// Pre-assign planner → `draft.segmentTemplate` (offsets), saved with Save draft.
class _DraftSegmentsEditor extends StatefulWidget {
  const _DraftSegmentsEditor({super.key});

  @override
  State<_DraftSegmentsEditor> createState() => _DraftSegmentsEditorState();
}

class _DraftSegmentsEditorState extends State<_DraftSegmentsEditor> {
  final controller = Get.find<RosterComposerController>();
  late List<SupportSegmentRowDraft> _rows;
  String? _localError;
  List<String> _warnings = const [];
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _rows = _hydrateRows();
  }

  List<String> get _participantIds => controller.draft.value.participantIds;

  List<SupportSegmentRowDraft> _hydrateRows() {
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    final template = controller.draft.value.segmentTemplate;
    final defaultName = controller.supportItemName.value;

    if (start == null || end == null) return [];

    if (template.isNotEmpty) {
      return supportSegmentRowsFromTemplate(
        template: template,
        windowStart: start,
        defaultItemName: defaultName.isEmpty ? null : defaultName,
      );
    }

    return seedDraftSegmentRows(
      windowStart: start,
      windowEnd: end,
      participantIds: _participantIds,
      supportItemCode: controller.draft.value.supportItemCode,
      supportItemName: defaultName.isEmpty ? null : defaultName,
    );
  }

  void _addRow() {
    if (_rows.length >= kMaxSupportSegments) {
      setState(() => _localError = 'At most $kMaxSupportSegments segments are allowed.');
      return;
    }
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    if (start == null || end == null) return;
    final ids = _participantIds;
    final defaultName = controller.supportItemName.value;
    setState(() {
      _localError = null;
      _dirty = true;
      _rows = [
        ..._rows,
        SupportSegmentRowDraft(
          shiftParticipantId: '',
          participantId: ids.isNotEmpty ? ids.first : null,
          anchorSupportItemCode:
              controller.draft.value.supportItemCode?.trim() ?? '',
          anchorSupportItemName: defaultName.isEmpty ? null : defaultName,
          startAt: start,
          endAt: end,
        ),
      ];
    });
  }

  void _removeRow(int index) {
    setState(() {
      _localError = null;
      _dirty = true;
      _rows = [
        for (var i = 0; i < _rows.length; i++)
          if (i != index) _rows[i],
      ];
      _warnings = supportSegmentKindWarnings(_rows);
    });
  }

  void _clearToModeA() {
    setState(() {
      _localError = null;
      _warnings = const [];
      _dirty = false;
      _rows = [];
    });
    controller.clearSegmentTemplate();
  }

  void _applyToDraft() {
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    if (start == null || end == null) {
      setState(() => _localError = 'Set the visit schedule before saving segments.');
      return;
    }
    if (_participantIds.isEmpty) {
      setState(
        () =>
            _localError =
                'Add at least one person before saving planned segments.',
      );
      return;
    }

    // Ensure each row has a participant id (default first).
    for (final row in _rows) {
      final id = (row.participantId ?? '').trim();
      if (id.isEmpty) {
        row.participantId = _participantIds.first;
      }
    }

    final validation = validateSupportSegmentRows(
      rows: _rows,
      visitStart: start,
      visitEnd: end,
      draftParticipantIds: _participantIds.toSet(),
      useParticipantId: true,
      requireCoverage: true,
    );
    if (validation != null) {
      setState(() {
        _localError = validation;
        _warnings = supportSegmentKindWarnings(_rows);
      });
      controller.segmentsError.value = validation;
      return;
    }

    final items = segmentTemplateFromRows(rows: _rows, windowStart: start);
    controller.setSegmentTemplate(items);
    setState(() {
      _localError = null;
      _warnings = supportSegmentKindWarnings(_rows);
      _dirty = false;
      _rows = _hydrateRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Touch draft fields so schedule / people / template updates rebuild.
      final start = controller.draft.value.scheduledStart;
      final end = controller.draft.value.scheduledEnd;
      final templateLen = controller.draft.value.segmentTemplate.length;
      final people = List<String>.from(controller.draft.value.participantIds);

      if (start == null || end == null) {
        return const Text(
          key: Key('segments-draft-need-schedule'),
          'Set start and end times before planning support windows.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        );
      }

      if (people.isEmpty && _rows.isEmpty) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              key: Key('segments-draft-mode-a-hint'),
              kDraftSegmentsModeACopy,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            SizedBox(height: 8),
            Text(
              'Add people on the People step to plan windows per participant.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (templateLen == 0) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                key: Key('segments-draft-mode-a-hint'),
                kDraftSegmentsModeACopy,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            if (!_dirty && _rows.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  key: Key('segments-draft-seed-hint'),
                  'Suggested full-window rows from the anchor item — edit and '
                  'save to the draft, or clear to keep Mode A.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
          ],
          if (shouldShowDualWorkerHint(
            workerCount: controller.workerSlotCount,
            rowKinds: _rows.map((r) => r.kind),
          ))
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                key: Key('segments-dual-worker-hint'),
                kDualWorkerSegmentsHint,
                style: TextStyle(color: AppColors.slate500, fontSize: 11),
              ),
            ),
          Text(
            key: const Key('segments-draft-cap'),
            '${_rows.length} / $kMaxSupportSegments segments',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++) ...[
            _SegmentRowCard(
              key: Key('segment-draft-row-$i'),
              index: i,
              row: _rows[i],
              draftParticipantIds: people,
              participantLabel: controller.participantName,
              visitEnd: end,
              showGroupSize: people.length > 1,
              canRemove: _rows.length > 1 || templateLen > 0,
              onChanged: () {
                setState(() {
                  _localError = null;
                  _dirty = true;
                  _warnings = supportSegmentKindWarnings(_rows);
                });
              },
              onRemove: () => _removeRow(i),
            ),
            const SizedBox(height: 12),
          ],
          if (_localError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _localError!,
                key: const Key('segments-draft-local-error'),
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
          for (final w in _warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                w,
                style: const TextStyle(color: AppColors.slate500, fontSize: 11),
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                key: const Key('segments-draft-add'),
                onPressed:
                    _rows.length >= kMaxSupportSegments ? null : _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add segment'),
              ),
              TextButton(
                key: const Key('segments-draft-clear'),
                onPressed:
                    templateLen == 0 && _rows.isEmpty ? null : _clearToModeA,
                child: const Text('Clear (Mode A)'),
              ),
              const Spacer(),
              TextButton(
                key: const Key('segments-draft-save'),
                onPressed: _rows.isEmpty ? null : _applyToDraft,
                child: Text(
                  _dirty || templateLen == 0 ? 'Save to draft' : 'Saved',
                ),
              ),
            ],
          ),
        ],
      );
    });
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
  List<String> _warnings = const [];

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

    // Live segments are source of truth after assign.
    if (existing.isNotEmpty) {
      return [
        for (final s in existing)
          SupportSegmentRowDraft(
            shiftParticipantId: s.shiftParticipantId,
            participantId: controller.participantIdForShiftParticipant(
              s.shiftParticipantId,
            ),
            anchorSupportItemCode: s.anchorSupportItemCode,
            anchorSupportItemName: s.anchorSupportItemName,
            kind: s.kind,
            startAt: s.startAt.toLocal(),
            endAt: s.endAt.toLocal(),
            groupSize: s.groupSize,
          ),
      ];
    }

    if (start == null || end == null) {
      return [];
    }

    // No live rows yet — expand draft template locally (kinds preserved).
    final template = controller.draft.value.segmentTemplate;
    if (template.isNotEmpty) {
      final expanded = expandTemplateRowsForLiveEditor(
        template: template,
        windowStart: start,
        participantIdToShiftParticipantId:
            controller.participantIdToShiftParticipantId,
        defaultItemName: defaultName.isEmpty ? null : defaultName,
      );
      if (expanded.isNotEmpty) return expanded;
    }

    if (participants.isEmpty) {
      return [];
    }

    // Mode A seed: one full-window direct segment per active participant.
    return [
      for (final p in participants)
        SupportSegmentRowDraft(
          shiftParticipantId: p.id,
          participantId: p.participantId,
          anchorSupportItemCode: defaultCode,
          anchorSupportItemName: defaultName.isEmpty ? null : defaultName,
          startAt: start,
          endAt: end,
        ),
    ];
  }

  void _addRow() {
    if (_rows.length >= kMaxSupportSegments) {
      setState(() => _localError = 'At most $kMaxSupportSegments segments are allowed.');
      return;
    }
    final start = controller.draft.value.scheduledStart;
    final end = controller.draft.value.scheduledEnd;
    if (start == null || end == null) return;
    final participants = _activeParticipants;
    final defaultSp = participants.isNotEmpty ? participants.first.id : '';
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
      _warnings = supportSegmentKindWarnings(_rows);
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
      setState(() {
        _localError = validation;
        _warnings = supportSegmentKindWarnings(_rows);
      });
      controller.segmentsError.value = validation;
      return;
    }

    setState(() {
      _localError = null;
      _warnings = supportSegmentKindWarnings(_rows);
    });
    await controller.saveVisitSegments(widget.visitId, [
      for (var i = 0; i < _rows.length; i++)
        SupportSegmentIn(
          shiftParticipantId: _rows[i].shiftParticipantId,
          anchorSupportItemCode: _rows[i].anchorSupportItemCode.trim(),
          kind: _rows[i].kind,
          startAt: _rows[i].startAt.toUtc(),
          endAt: _rows[i].endAt.toUtc(),
          groupSize: _rows[i].groupSize,
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
      final end = controller.draft.value.scheduledEnd;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Visit $shortId',
            style: const TextStyle(fontSize: 12, color: AppColors.slate500),
          ),
          const SizedBox(height: 4),
          Text(
            '${_rows.length} / $kMaxSupportSegments segments',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          if (shouldShowDualWorkerHint(
            workerCount: controller.workerSlotCount,
            rowKinds: _rows.map((r) => r.kind),
          ))
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                key: Key('segments-live-dual-worker-hint'),
                kDualWorkerSegmentsHint,
                style: TextStyle(color: AppColors.slate500, fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          for (var i = 0; i < _rows.length; i++) ...[
            _SegmentRowCard(
              key: Key('segment-row-${widget.visitId}-$i'),
              index: i,
              row: _rows[i],
              participants: participants,
              visitEnd: end,
              showGroupSize: participants.length > 1,
              canRemove: _rows.length > 1 && !saving,
              onChanged: () {
                setState(() {
                  _localError = null;
                  _warnings = supportSegmentKindWarnings(_rows);
                });
              },
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
          for (final w in _warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                w,
                style: const TextStyle(color: AppColors.slate500, fontSize: 11),
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                key: Key('segments-add-${widget.visitId}'),
                onPressed:
                    saving || _rows.length >= kMaxSupportSegments
                        ? null
                        : _addRow,
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
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    this.participants = const [],
    this.draftParticipantIds = const [],
    this.participantLabel,
    this.visitEnd,
    this.showGroupSize = false,
  });

  final int index;
  final SupportSegmentRowDraft row;
  final List<ShiftParticipantOut> participants;
  final List<String> draftParticipantIds;
  final String? Function(String id)? participantLabel;
  final DateTime? visitEnd;
  final bool showGroupSize;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  bool get _useDraftParticipants => draftParticipantIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final kind =
        kSupportSegmentKinds.contains(row.kind) ? row.kind : 'direct';
    final kindHelp = supportSegmentKindHelper(kind);

    String? selectedSp;
    if (_useDraftParticipants) {
      final id = (row.participantId ?? '').trim();
      selectedSp =
          draftParticipantIds.contains(id)
              ? id
              : (draftParticipantIds.isNotEmpty
                  ? draftParticipantIds.first
                  : null);
    } else {
      final participantIds = {for (final p in participants) p.id};
      selectedSp =
          participantIds.contains(row.shiftParticipantId)
              ? row.shiftParticipantId
              : (participants.isNotEmpty ? participants.first.id : null);
    }

    final showParticipantDropdown =
        _useDraftParticipants
            ? draftParticipantIds.length > 1
            : participants.length > 1;

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
          if (showParticipantDropdown) ...[
            DropdownButtonFormField<String>(
              key: Key('segment-participant-$index'),
              value: selectedSp,
              decoration: const InputDecoration(
                labelText: 'Participant',
                isDense: true,
              ),
              items: [
                if (_useDraftParticipants)
                  for (final id in draftParticipantIds)
                    DropdownMenuItem(
                      value: id,
                      child: Text(
                        participantLabel?.call(id)?.trim().isNotEmpty == true
                            ? participantLabel!(id)!
                            : 'Participant',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                else
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
                if (_useDraftParticipants) {
                  row.participantId = v;
                } else {
                  row.shiftParticipantId = v;
                }
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
          if (kindHelp != null) ...[
            const SizedBox(height: 4),
            Text(
              kindHelp,
              key: Key('segment-kind-help-$index'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          if (showGroupSize) ...[
            const SizedBox(height: 8),
            TextFormField(
              key: Key('segment-group-size-$index'),
              initialValue:
                  row.groupSize == null ? '' : row.groupSize.toString(),
              decoration: const InputDecoration(
                labelText: 'Group size (optional)',
                helperText: 'Participants in the group for this window, not workers',
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final trimmed = v.trim();
                if (trimmed.isEmpty) {
                  row.groupSize = null;
                } else {
                  row.groupSize = int.tryParse(trimmed);
                }
                onChanged();
              },
            ),
          ],
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
                    // Re-resolve end if overnight.
                    row.endAt = resolveSegmentEndAt(
                      startAt: row.startAt,
                      endHour: row.endAt.hour,
                      endMinute: row.endAt.minute,
                      visitEnd: visitEnd,
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
                    row.endAt = resolveSegmentEndAt(
                      startAt: row.startAt,
                      endHour: t.hour,
                      endMinute: t.minute,
                      visitEnd: visitEnd,
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
