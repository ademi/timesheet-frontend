import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../data/composer_models.dart';
import '../roster_composer_controller.dart';

/// Publish anchor + post-assign segment editor (A3).
///
/// Keeps a simple code field for the v1 publish anchor (NDIS picker needs
/// BillingBinding and would break Task 3 widget smoke tests). Segment editor
/// appears only when a visit exists after assign.
class ComposerSupportSection extends GetView<RosterComposerController> {
  const ComposerSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final code = controller.draft.value.supportItemCode ?? '';
      final visitIds = controller.visitIdsWithSegments;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Support', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Anchor item for publish.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('support-$code'),
            initialValue: code,
            decoration: const InputDecoration(
              labelText: 'Support item code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => controller.setSupportItemCode(v.trim()),
          ),
          if (visitIds.isNotEmpty) ...[
            const SizedBox(height: 16),
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

class _VisitSegmentsEditor extends StatefulWidget {
  const _VisitSegmentsEditor({super.key, required this.visitId});

  final String visitId;

  @override
  State<_VisitSegmentsEditor> createState() => _VisitSegmentsEditorState();
}

class _VisitSegmentsEditorState extends State<_VisitSegmentsEditor> {
  late final TextEditingController _codeCtrl;
  final controller = Get.find<RosterComposerController>();

  @override
  void initState() {
    super.initState();
    final segments = controller.segmentsByVisit[widget.visitId] ?? const [];
    _codeCtrl = TextEditingController(
      text:
          segments.isNotEmpty
              ? segments.first.anchorSupportItemCode
              : (controller.draft.value.supportItemCode ?? ''),
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
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
          TextFormField(
            controller: _codeCtrl,
            decoration: const InputDecoration(
              labelText: 'Segment anchor item',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: Key('segments-save-${widget.visitId}'),
              onPressed:
                  saving || start == null || end == null || defaultSp.isEmpty
                      ? null
                      : () async {
                        final code = _codeCtrl.text.trim();
                        if (code.isEmpty) return;
                        await controller.saveVisitSegments(widget.visitId, [
                          SupportSegmentIn(
                            shiftParticipantId: defaultSp,
                            anchorSupportItemCode: code,
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
