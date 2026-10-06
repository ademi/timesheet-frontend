import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/views/widgets/app_back_button.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/contractor_visits_controller.dart';
import '../controllers/visit_shift_brief_controller.dart';
import '../data/models/visit_models.dart';
import '../services/visit_location_service.dart';
import '../widgets/shift_brief_panel.dart';
import '../widgets/visit_schema_form.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

String _statusLabel(String status) {
  switch (status) {
    case 'scheduled':
      return 'Scheduled';
    case 'checked_in':
      return 'Checked in';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status;
  }
}

({Color fg, Color bg}) _statusColors(String status) {
  switch (status) {
    case 'checked_in':
      return (fg: AppColors.brandDark, bg: AppColors.brandSoft);
    case 'completed':
      return (fg: AppColors.success, bg: AppColors.successBackground);
    case 'cancelled':
      return (fg: AppColors.error, bg: AppColors.errorBackground);
    default:
      return (fg: AppColors.slate700, bg: AppColors.slate200);
  }
}

class ContractorVisitDetailView extends StatefulWidget {
  const ContractorVisitDetailView({super.key});

  @override
  State<ContractorVisitDetailView> createState() =>
      _ContractorVisitDetailViewState();
}

class _ContractorVisitDetailViewState extends State<ContractorVisitDetailView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<ContractorVisitsController>();
    c.hydrateFromArgs();
    _loadShiftBrief(c.resolvedVisitId);
    c.refreshSelected().then((_) => _loadShiftBrief(c.resolvedVisitId));
  }

  void _loadShiftBrief(String? visitId) {
    if (visitId != null && Get.isRegistered<VisitShiftBriefController>()) {
      Get.find<VisitShiftBriefController>().load(visitId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<ContractorVisitsController>();
    final briefCtrl =
        Get.isRegistered<VisitShiftBriefController>()
            ? Get.find<VisitShiftBriefController>()
            : null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRoute: AppRoutes.contractorVisits,
        ),
        title: const Text('Visit detail'),
      ),
      body: Obx(() {
        controller.mediaOutboxRevision.value;
        controller.formDraftRevision.value;
        final v = controller.selected.value;
        final err = controller.errorMessage.value;
        if (v == null) {
          if (controller.isRefreshing.value ||
              controller.resolvedVisitId != null) {
            return const Center(child: CircularProgressIndicator());
          }
          return const Center(child: Text('Visit not loaded.'));
        }
        final gpsBlocked = controller.isWeb;
        final reqs = controller.effectiveFormRequirements;
        final brief = briefCtrl?.brief.value;
        final briefLoading = briefCtrl?.isLoading.value ?? false;
        final briefErr = briefCtrl?.errorMessage.value;
        final showCheckIn = v.isScheduled && controller.canCheckIn;
        final showComplete = v.isCheckedIn && controller.canComplete;
        final showFooter = showCheckIn || showComplete;

        return Column(
          children: [
            if (controller.isRefreshing.value)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        _VisitHeader(visit: v),
                        if (v.locationLabel?.isNotEmpty == true ||
                            (v.latitude != null && v.longitude != null)) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed:
                                  () => openMapLocation(
                                    latitude: v.latitude,
                                    longitude: v.longitude,
                                    label: v.locationLabel,
                                  ),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: Text(
                                v.locationLabel?.isNotEmpty == true
                                    ? v.locationLabel!
                                    : 'Open in Maps',
                              ),
                            ),
                          ),
                        ],
                        if (gpsBlocked) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.brandSoft.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              VisitLocationService.webBlockedMessage,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                        if (controller.selectedSyncUi !=
                            VisitClockSyncUi.none) ...[
                          const SizedBox(height: 12),
                          _SyncChip(
                            failed:
                                controller.selectedSyncUi ==
                                VisitClockSyncUi.failed,
                            onRetry: controller.retryPendingSync,
                            onDismiss: controller.dismissConflictForSelected,
                          ),
                        ],
                        if (briefCtrl != null)
                          ShiftBriefPanel(
                            brief: brief,
                            isLoading: briefLoading,
                            errorMessage: briefErr,
                          ),
                        if (v.shiftId != null && v.shiftId!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text('Trip kms', style: Get.textTheme.titleMedium),
                          const SizedBox(height: 4),
                          const Text(
                            'Enter kilometres for this shift. Saved once into '
                            'the travel claim used on invoice export.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _TripKmsEditor(
                            initialKms: v.tripKms,
                            enabled: !controller.isSaving.value,
                            onSave: controller.saveTripKms,
                          ),
                        ],
                        const SizedBox(height: 20),
                        _TasksSection(
                          tasks: v.tasks,
                          enabled:
                              !controller.isSaving.value &&
                              (v.isCheckedIn || v.isScheduled),
                          onToggle: controller.toggleTask,
                        ),
                        if (v.isCheckedIn || v.isCompleted) ...[
                          const SizedBox(height: 20),
                          _FormsAccordion(
                            key: ValueKey(
                              '${v.id}-${reqs.map((r) => r.formTemplateId).join(',')}',
                            ),
                            requirements: reqs,
                            visit: v,
                            controller: controller,
                          ),
                        ],
                        if (v.isCompleted)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'This visit is completed.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        if (v.isCancelled)
                          const Padding(
                            padding: EdgeInsets.only(top: 16),
                            child: Text(
                              'This visit was cancelled.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showFooter)
              _VisitActionBar(
                showCheckIn: showCheckIn,
                showComplete: showComplete,
                gpsBlocked: gpsBlocked,
                isSaving: controller.isSaving.value,
                onCheckIn: controller.checkIn,
                onComplete: controller.complete,
              ),
          ],
        );
      }),
    );
  }
}

class _VisitHeader extends StatelessWidget {
  const _VisitHeader({required this.visit});

  final VisitOut visit;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(visit.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          visit.jobTitle ?? visit.tenantName ?? 'Visit',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _statusLabel(visit.status),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.fg,
                ),
              ),
            ),
            Text(
              '${_fmt(visit.scheduledStart)} → ${_fmt(visit.scheduledEnd)}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VisitActionBar extends StatelessWidget {
  const _VisitActionBar({
    required this.showCheckIn,
    required this.showComplete,
    required this.gpsBlocked,
    required this.isSaving,
    required this.onCheckIn,
    required this.onComplete,
  });

  final bool showCheckIn;
  final bool showComplete;
  final bool gpsBlocked;
  final bool isSaving;
  final Future<void> Function() onCheckIn;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.textDark.withValues(alpha: 0.12),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: PageContent(
            width: PageContentWidth.narrow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCheckIn)
                  AsyncElevatedButton(
                    onPressed: gpsBlocked ? null : onCheckIn,
                    isLoading: isSaving,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: AppColors.onCta,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Check in'),
                  ),
                if (showComplete)
                  AsyncElevatedButton(
                    onPressed: gpsBlocked ? null : onComplete,
                    isLoading: isSaving,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: AppColors.onCta,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Complete'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TasksSection extends StatelessWidget {
  const _TasksSection({
    required this.tasks,
    required this.enabled,
    required this.onToggle,
  });

  final List<VisitTaskOut> tasks;
  final bool enabled;
  final Future<void> Function(VisitTaskOut) onToggle;

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.isDone).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Tasks', style: Get.textTheme.titleMedium),
            ),
            if (tasks.isNotEmpty)
              Text(
                '$done of ${tasks.length} done',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'No tasks for this visit.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else
          for (final t in tasks)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: t.isDone,
              title: Text(t.title),
              onChanged: enabled ? (_) => onToggle(t) : null,
            ),
      ],
    );
  }
}

/// Accordion of visit forms — one open at a time; collapsed by default except
/// the first incomplete required form.
class _FormsAccordion extends StatefulWidget {
  const _FormsAccordion({
    super.key,
    required this.requirements,
    required this.visit,
    required this.controller,
  });

  final List<VisitFormRequirement> requirements;
  final VisitOut visit;
  final ContractorVisitsController controller;

  @override
  State<_FormsAccordion> createState() => _FormsAccordionState();
}

class _FormsAccordionState extends State<_FormsAccordion> {
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _expandedId = _defaultExpandedId();
  }

  String? _defaultExpandedId() {
    for (final req in widget.requirements) {
      final done = widget.controller.isFormSubmitted(req.formTemplateId);
      if (!done && req.isRequired) return req.formTemplateId;
    }
    for (final req in widget.requirements) {
      if (!widget.controller.isFormSubmitted(req.formTemplateId)) {
        return req.formTemplateId;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final reqs = widget.requirements;
    final submittedCount =
        reqs
            .where((r) => widget.controller.isFormSubmitted(r.formTemplateId))
            .length;
    final remaining = reqs.length - submittedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Forms', style: Get.textTheme.titleMedium),
            ),
            if (reqs.isNotEmpty)
              Text(
                remaining == 0
                    ? 'All submitted'
                    : '$remaining remaining',
                key: const Key('visit-forms-summary'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      remaining == 0
                          ? AppColors.brand
                          : AppColors.textMuted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap a form to expand. Only one stays open at a time.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        if (reqs.isEmpty)
          const Text(
            'No forms required for this visit.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          )
        else
          for (final req in reqs)
            _FormExpansionTile(
              key: Key('visit-form-tile-${req.formTemplateId}'),
              requirement: req,
              expanded: _expandedId == req.formTemplateId,
              isSubmitted: widget.controller.isFormSubmitted(
                req.formTemplateId,
              ),
              syncLabel: () {
                switch (widget.controller.formSyncUiFor(
                  visitId: widget.visit.id,
                  formTemplateId: req.formTemplateId,
                )) {
                  case FormDraftSyncUi.draft:
                    return 'Draft on device';
                  case FormDraftSyncUi.pending:
                    return 'Pending sync';
                  case FormDraftSyncUi.failed:
                    return 'Sync failed';
                  case FormDraftSyncUi.none:
                    return null;
                }
              }(),
              onExpansionChanged: (open) {
                setState(() {
                  _expandedId = open ? req.formTemplateId : null;
                });
              },
              child: VisitSchemaForm(
                embedded: true,
                requirement: req,
                canSubmit: widget.visit.isCheckedIn,
                isSubmitting: widget.controller.isSaving.value,
                isSubmitted: widget.controller.isFormSubmitted(
                  req.formTemplateId,
                ),
                visitId: widget.visit.id,
                initialDraftPayload:
                    widget.controller
                        .formDraftFor(
                          visitId: widget.visit.id,
                          formTemplateId: req.formTemplateId,
                        )
                        ?.payloadJson,
                syncStatusLabel: () {
                  switch (widget.controller.formSyncUiFor(
                    visitId: widget.visit.id,
                    formTemplateId: req.formTemplateId,
                  )) {
                    case FormDraftSyncUi.draft:
                      return 'Draft saved on device';
                    case FormDraftSyncUi.pending:
                      return 'Pending sync';
                    case FormDraftSyncUi.failed:
                      return 'Sync failed';
                    case FormDraftSyncUi.none:
                      return null;
                  }
                }(),
                onDraftChanged:
                    (payload) => widget.controller.saveFormDraft(
                      visitId: widget.visit.id,
                      formTemplateId: req.formTemplateId,
                      payloadJson: payload,
                      supportItemCode: widget.visit.supportItemCode,
                    ),
                onRetryFormSync: widget.controller.retryFormDrafts,
                onEnqueueFile: ({
                  required fieldId,
                  required filename,
                  required contentType,
                  required bytes,
                }) =>
                    widget.controller.enqueueVisitFormFile(
                      visitId: widget.visit.id,
                      formTemplateId: req.formTemplateId,
                      fieldId: fieldId,
                      filename: filename,
                      contentType: contentType,
                      bytes: bytes,
                    ),
                pendingFileForField: widget.controller.mediaPendingForField,
                ackedDocumentIdForField:
                    (fieldId) =>
                        widget.controller.ackedMediaDocumentIds[fieldId],
                onRetryMedia: widget.controller.retryMediaUploads,
                onSubmit:
                    (payload) => widget.controller.submitForm(
                      req,
                      payloadJson: payload,
                    ),
              ),
            ),
        if (widget.visit.formSubmissions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Submissions on file: ${widget.visit.formSubmissions.length}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _FormExpansionTile extends StatelessWidget {
  const _FormExpansionTile({
    super.key,
    required this.requirement,
    required this.expanded,
    required this.isSubmitted,
    required this.onExpansionChanged,
    required this.child,
    this.syncLabel,
  });

  final VisitFormRequirement requirement;
  final bool expanded;
  final bool isSubmitted;
  final String? syncLabel;
  final ValueChanged<bool> onExpansionChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = requirement.name ?? 'Form';
    final statusColor =
        isSubmitted
            ? AppColors.brand
            : (requirement.isRequired ? AppColors.openSlot : AppColors.slate600);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color:
                expanded
                    ? AppColors.brand.withValues(alpha: 0.45)
                    : AppColors.slate200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onExpansionChanged(!expanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (isSubmitted)
                                'Submitted'
                              else if (requirement.isRequired)
                                'Required'
                              else
                                'Optional',
                              if (syncLabel != null && !isSubmitted) syncLabel!,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Keep form state mounted while collapsed so drafts survive toggles.
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: expanded ? 1 : 0,
                child: Offstage(
                  offstage: !expanded,
                  child: TickerMode(
                    enabled: expanded,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncChip extends StatelessWidget {
  const _SyncChip({
    required this.failed,
    required this.onRetry,
    required this.onDismiss,
  });

  final bool failed;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            failed
                ? AppColors.errorBackground
                : AppColors.brandSoft.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            failed ? Icons.sync_problem : Icons.cloud_upload_outlined,
            size: 18,
            color: failed ? AppColors.error : AppColors.brand,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              failed
                  ? 'Sync conflict — staff must resolve, then dismiss'
                  : 'Pending sync',
              style: TextStyle(
                color: failed ? AppColors.error : AppColors.textMuted,
              ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () => onDismiss(),
              child: const Text('Dismiss'),
            )
          else
            TextButton(
              onPressed: () => onRetry(),
              child: const Text('Retry'),
            ),
        ],
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

class _TripKmsEditor extends StatefulWidget {
  const _TripKmsEditor({
    required this.initialKms,
    required this.enabled,
    required this.onSave,
  });

  final double? initialKms;
  final bool enabled;
  final Future<void> Function(double kms) onSave;

  @override
  State<_TripKmsEditor> createState() => _TripKmsEditorState();
}

class _TripKmsEditorState extends State<_TripKmsEditor> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialKms != null ? widget.initialKms.toString() : '',
    );
  }

  @override
  void didUpdateWidget(covariant _TripKmsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialKms != widget.initialKms) {
      _ctrl.text =
          widget.initialKms != null ? widget.initialKms.toString() : '';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Kilometres',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed:
              widget.enabled
                  ? () {
                    final kms = double.tryParse(_ctrl.text.trim());
                    if (kms == null) return;
                    widget.onSave(kms);
                  }
                  : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
