import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/attendance_review_controller.dart';
import '../data/attendance_review_models.dart';

/// Prefer a short visit ref over a full UUID in list subtitles.
String attendanceVisitSubtitleRef(String visitId) {
  final trimmed = visitId.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.length <= 8) return trimmed;
  return trimmed.substring(0, 8);
}

class AttendanceReviewView extends GetView<AttendanceReviewController> {
  const AttendanceReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Attendance review')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final actionErr = controller.actionError.value;
        final filter = controller.filter.value;
        final rows = controller.visibleItems;
        return Column(
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBox(err),
              ),
            if (actionErr != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _ErrorBox(actionErr),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: filter == AttendanceReviewFilter.all,
                    onSelected: (_) =>
                        controller.setFilter(AttendanceReviewFilter.all),
                  ),
                  ChoiceChip(
                    label: const Text('GPS'),
                    selected: filter == AttendanceReviewFilter.gps,
                    onSelected: (_) =>
                        controller.setFilter(AttendanceReviewFilter.gps),
                  ),
                  ChoiceChip(
                    label: const Text('Sync'),
                    selected: filter == AttendanceReviewFilter.sync,
                    onSelected: (_) =>
                        controller.setFilter(AttendanceReviewFilter.sync),
                  ),
                ],
              ),
            ),
            if (controller.visitIdFilter != null &&
                controller.visitIdFilter!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filtered to this visit',
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            Expanded(
              child:
                  controller.isLoading.value && rows.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: controller.load,
                        child:
                            rows.isEmpty
                                ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 80),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'You\'re all caught up',
                                            textAlign: TextAlign.center,
                                            style: Get.textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No GPS exceptions or sync conflicts '
                                            'need review right now.',
                                            textAlign: TextAlign.center,
                                            style: Get.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          TextButton.icon(
                                            onPressed:
                                                () => Get.toNamed(
                                                  AppRoutes.staffVisits,
                                                ),
                                            icon: const Icon(
                                              Icons.calendar_today_outlined,
                                            ),
                                            label: const Text('Go to visits'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                                : ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: rows.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final item = rows[index];
                                    return PageContent(
                                      width: PageContentWidth.narrow,
                                      child: _ReviewTile(
                                        item: item,
                                        busy: controller.isActing.value,
                                        onApprove:
                                            () => _promptNote(
                                              context,
                                              title: 'Approve GPS exception',
                                              confirmLabel: 'Approve',
                                              requireMinLength: 0,
                                              onConfirm:
                                                  (note) => controller
                                                      .approveException(
                                                        item,
                                                        note: note,
                                                      ),
                                            ),
                                        onReject:
                                            () => _promptNote(
                                              context,
                                              title: 'Reject GPS exception',
                                              confirmLabel: 'Reject',
                                              requireMinLength: 0,
                                              onConfirm:
                                                  (note) => controller
                                                      .rejectException(
                                                        item,
                                                        note: note,
                                                      ),
                                            ),
                                        onForceAccept:
                                            () => _promptNote(
                                              context,
                                              title:
                                                  'Record attendance despite failed clock?',
                                              body:
                                                  'This writes attendance from the '
                                                  'contractor\'s frozen punch even '
                                                  'though the clock sync failed. '
                                                  'Only continue if you have verified '
                                                  'the visit happened.',
                                              confirmLabel: 'Force accept',
                                              requireMinLength:
                                                  AttendanceReviewController
                                                      .forceAcceptNoteMinLength,
                                              onConfirm:
                                                  (note) => controller
                                                      .forceAcceptConflict(
                                                        item,
                                                        note: note,
                                                      ),
                                            ),
                                        onDiscard:
                                            () => _promptNote(
                                              context,
                                              title: 'Discard sync conflict',
                                              confirmLabel: 'Discard',
                                              requireMinLength: 1,
                                              onConfirm:
                                                  (note) => controller
                                                      .discardConflict(
                                                        item,
                                                        note: note,
                                                      ),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                      ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _promptNote(
    BuildContext context, {
    required String title,
    String? body,
    required String confirmLabel,
    required int requireMinLength,
    required Future<bool> Function(String note) onConfirm,
  }) async {
    final noteCtrl = TextEditingController();
    final result = await Get.dialog<String>(
      StatefulBuilder(
        builder: (context, setState) {
          final noteLen = noteCtrl.text.trim().length;
          final canConfirm =
              requireMinLength <= 0 || noteLen >= requireMinLength;
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (body != null) ...[
                  Text(
                    body,
                    style: Get.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: noteCtrl,
                  autofocus: true,
                  maxLines: 3,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText:
                        requireMinLength > 0
                            ? 'Note (min $requireMinLength characters)'
                            : 'Note (optional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancel'),
              ),
              AsyncElevatedButton(
                onPressed:
                    canConfirm
                        ? () => Get.back(result: noteCtrl.text)
                        : null,
                isLoading: false,
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      ),
    );
    noteCtrl.dispose();
    if (result == null) return;
    await onConfirm(result);
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.item,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onForceAccept,
    required this.onDiscard,
  });

  final AttendanceReviewItem item;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onForceAccept;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final isGps = item.kind == AttendanceReviewKind.exception;
    final visitRef = attendanceVisitSubtitleRef(item.visitId);
    final subtitle = visitRef.isEmpty
        ? item.detail
        : '${item.detail} · $visitRef';
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KindBadge(kind: item.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.headline, style: Get.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        item.sortAt.toLocal().toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  isGps
                      ? [
                        OutlinedButton(
                          onPressed: busy ? null : onReject,
                          child: const Text('Reject'),
                        ),
                        ElevatedButton(
                          onPressed: busy ? null : onApprove,
                          child: const Text('Approve'),
                        ),
                      ]
                      : [
                        OutlinedButton(
                          onPressed: busy ? null : onDiscard,
                          child: const Text('Discard'),
                        ),
                        ElevatedButton(
                          onPressed: busy ? null : onForceAccept,
                          child: const Text('Force accept'),
                        ),
                      ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final AttendanceReviewKind kind;

  @override
  Widget build(BuildContext context) {
    final isGps = kind == AttendanceReviewKind.exception;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isGps
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGps ? 'GPS' : 'Sync',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isGps ? AppColors.primary : AppColors.openSlot,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
