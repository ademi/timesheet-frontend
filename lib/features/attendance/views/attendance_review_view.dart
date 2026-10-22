import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/attendance_review_controller.dart';
import '../data/attendance_review_models.dart';
import '../widgets/attendance_tab_info_sheet.dart';

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
      appBar: AppBar(title: const Text('Attendance & variance')),
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
                runSpacing: 8,
                children: [
                  for (final tab in AttendanceReviewFilter.values)
                    _AttendanceFilterChip(
                      filter: tab,
                      selected: filter == tab,
                      onSelect: () => controller.setFilter(tab),
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
                                                () => AppNavigator.go(
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

class _AttendanceFilterChip extends StatelessWidget {
  const _AttendanceFilterChip({
    required this.filter,
    required this.selected,
    required this.onSelect,
  });

  final AttendanceReviewFilter filter;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    // Custom chip (not FilterChip) so the (i) IconButton can receive taps —
    // nested gestures inside FilterChip labels are swallowed by the chip.
    final fg = selected ? AppColors.onCta : AppColors.textDark;
    final bg = selected ? AppColors.cta : AppColors.surface;
    final border =
        selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.textDark, width: 1);
    final infoFg =
        selected
            ? AppColors.onCta.withValues(alpha: 0.9)
            : AppColors.textMuted;

    // Squared chip with small rounded corners (not pill / stadium).
    const radius = BorderRadius.all(Radius.circular(8));
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: radius, side: border),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onSelect,
              borderRadius: radius,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 2, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(Icons.check, size: 16, color: fg),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      filter.shortLabel,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 36),
              tooltip: 'About ${filter.shortLabel}',
              icon: Icon(Icons.info_outline, size: 15, color: infoFg),
              onPressed:
                  () => showAttendanceTabInfoSheet(context, tab: filter),
            ),
          ],
        ),
      ),
    );
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
    final ctx = item.visitContext;
    final muted = const TextStyle(fontSize: 12, color: AppColors.textMuted);
    final visitRef = attendanceVisitSubtitleRef(item.visitId);
    final metaParts = <String>[
      if (item.detail.trim().isNotEmpty) item.detail.trim(),
      if (visitRef.isNotEmpty) visitRef,
    ];
    final distanceLabel = item.geofence?.distanceLabel;
    final contractor = ctx?.contractorName?.trim();
    final client = ctx?.clientName?.trim();
    final location = ctx?.locationLabel?.trim();
    final stop = item.geofence?.nearestStopLabel?.trim();
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
                      if (contractor != null && contractor.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(contractor, style: Get.textTheme.bodyMedium),
                      ],
                      if (client != null && client.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Client: $client', style: muted),
                      ],
                      if (location != null && location.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(location, style: muted),
                      ],
                      if (distanceLabel != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          stop != null &&
                                  stop.isNotEmpty &&
                                  stop.toLowerCase() != 'visit'
                              ? '$distanceLabel · nearest: $stop'
                              : distanceLabel,
                          style: muted.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(metaParts.join(' · '), style: muted),
                      ],
                      Text(item.sortAt.toLocal().toString(), style: muted),
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
