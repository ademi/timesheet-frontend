import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/widgets/ndis_support_item_picker.dart';
import '../../../data/composer_models.dart';
import '../roster_composer_controller.dart';

/// Publish anchor + post-assign segment editor (A3).
class ComposerSupportSection extends GetView<RosterComposerController> {
  const ComposerSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final code = controller.draft.value.supportItemCode;
      final name = controller.supportItemName.value;
      final visitIds = controller.visitIdsWithSegments;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Support', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Anchor NDIS item for publish.',
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
