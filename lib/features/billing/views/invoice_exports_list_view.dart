import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/equal_fill_row.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../visits/data/models/visit_models.dart';
import '../controllers/invoice_exports_controller.dart';
import '../data/models/billing_models.dart';
import '../utils/visit_export_preflight.dart';
import '../widgets/billing_ui.dart';

String? _clientDropdownValue(
  String? filter,
  Iterable<({String id, String name})> clients,
) {
  if (filter == null || filter.isEmpty) return null;
  for (final c in clients) {
    if (c.id == filter) return filter;
  }
  return null;
}

List<DropdownMenuItem<String>> _clientDropdownItems(
  Iterable<({String id, String name})> clients, {
  String allLabel = 'All clients',
}) {
  return [
    DropdownMenuItem(value: null, child: Text(allLabel)),
    for (final c in clients)
      DropdownMenuItem(
        value: c.id,
        child: Text(c.name, overflow: TextOverflow.ellipsis),
      ),
  ];
}

class InvoiceExportsListView extends GetView<InvoiceExportsController> {
  const InvoiceExportsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice exports'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final tab = controller.tabIndex.value;
        final err = controller.errorMessage.value;
        final loading = controller.isLoading.value;
        final showCreate = tab == 1 && controller.canManage;
        final showAgeing = tab == 2;
        final showBurn = tab == 3;
        final showPe = tab == 4;

        return Column(
          children: [
            PageContent(
              width: PageContentWidth.workflow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null) ...[
                      BillingErrorBox(err),
                      const SizedBox(height: 12),
                    ],
                    if (controller.canView)
                      Semantics(
                        label: 'Export mode',
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<int>(
                            segments: [
                              const ButtonSegment(
                                value: 0,
                                label: Text('Exports'),
                                icon: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                ),
                              ),
                              if (controller.canManage)
                                const ButtonSegment(
                                  value: 1,
                                  label: Text('Create'),
                                  icon: Icon(Icons.add, size: 18),
                                ),
                              ButtonSegment(
                                value: 2,
                                label: Text(
                                  controller.hasAgeingRiskBadge
                                      ? '90d (${controller.ageingRiskCount})'
                                      : '90d',
                                ),
                                icon: const Icon(
                                  Icons.schedule_outlined,
                                  size: 18,
                                ),
                              ),
                              ButtonSegment(
                                value: 3,
                                label: Text(
                                  controller.hasBurnAlertBadge
                                      ? 'Burn (${controller.burnAlertCount})'
                                      : 'Burn',
                                ),
                                icon: Icon(
                                  Icons.local_fire_department_outlined,
                                  size: 18,
                                  color:
                                      controller.hasBurnAlertBadge
                                          ? AppColors.error
                                          : null,
                                ),
                              ),
                              const ButtonSegment(
                                value: 4,
                                label: Text('PE'),
                                icon: Icon(Icons.outgoing_mail, size: 18),
                              ),
                            ],
                            selected: {tab},
                            onSelectionChanged: (next) {
                              final v = next.first;
                              if (v == 1) {
                                controller.switchToCreateTab();
                              } else if (v == 2) {
                                controller.switchToAgeingTab();
                              } else if (v == 3) {
                                controller.switchToBurnTab();
                              } else if (v == 4) {
                                controller.switchToPeTab();
                              } else {
                                controller.tabIndex.value = 0;
                              }
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.onPrimary;
                                }
                                return AppColors.textDark;
                              }),
                              backgroundColor: WidgetStateProperty.resolveWith((
                                states,
                              ) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.dark;
                                }
                                return AppColors.primaryLight;
                              }),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey('billing-tab-$tab'),
                  child:
                      showBurn
                          ? _BurnTab(controller: controller)
                          : showPe
                          ? _PeTab(controller: controller)
                          : showAgeing
                          ? _AgeingTab(controller: controller)
                          : showCreate
                          ? _CreateExportTab(controller: controller)
                          : _ExportsTab(controller: controller),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ExportsTab extends StatelessWidget {
  const _ExportsTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return RefreshIndicator(
        onRefresh: controller.loadExports,
        child:
            controller.exports.isEmpty && !controller.isLoading.value
                ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    PageContent(
                      width: PageContentWidth.workflow,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Column(
                          children: [
                            const Text(
                              'No invoice exports yet.',
                              style: TextStyle(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                            if (controller.canManage) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: controller.switchToCreateTab,
                                child: const Text('Create an export'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.exports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final export = controller.exports[index];
                    return PageContent(
                      width: PageContentWidth.workflow,
                      child: _ExportTile(
                        export: export,
                        onTap: () => controller.openDetail(export),
                      ),
                    );
                  },
                ),
      );
    });
  }
}

class _CreateExportTab extends StatelessWidget {
  const _CreateExportTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hint = controller.createExportHint;
      final clients = controller.clientFilterOptions;
      final clientFilter = controller.clientIdFilter.value;
      final participants = controller.participantFilterOptions;
      final participantFilter = controller.participantIdFilter.value;
      final jobOptions = controller.jobFilterOptions;
      final jobFilter = controller.jobIdFilter.value;
      return Column(
        children: [
          PageContent(
            width: PageContentWidth.workflow,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EqualFillRow(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _clientDropdownValue(clientFilter, clients),
                        isExpanded: true,
                        items: _clientDropdownItems(clients, allLabel: 'All hosts'),
                        onChanged: controller.setClientFilter,
                        decoration: const InputDecoration(
                          labelText: 'Host client',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        value: _clientDropdownValue(
                          participantFilter,
                          participants,
                        ),
                        isExpanded: true,
                        items: _clientDropdownItems(
                          participants,
                          allLabel: 'All participants',
                        ),
                        onChanged: controller.setParticipantFilter,
                        decoration: const InputDecoration(
                          labelText: 'Participant',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  EqualFillRow(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _clientDropdownValue(jobFilter, jobOptions),
                        isExpanded: true,
                        items: _clientDropdownItems(
                          jobOptions,
                          allLabel: 'All jobs / shifts',
                        ),
                        onChanged: controller.setJobFilter,
                        decoration: const InputDecoration(
                          labelText: 'Job / support',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      _PeriodFilterField(
                        range: controller.periodRange.value,
                        onPick: () => controller.pickPeriod(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select completed visits to export as NDIS '
                    'plan-manager CSV lines.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.loadExportableVisits,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                children: [
                  PageContent(
                    width: PageContentWidth.workflow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.lastVisitErrors.isNotEmpty) ...[
                          const Text(
                            'Export issues',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          for (final err in controller.lastVisitErrors)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${controller.visitLabelForError(err)}: '
                                '${err.message}',
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                        if (controller.exportableVisits.isEmpty &&
                            !controller.isLoading.value)
                          Text(
                            clientFilter.isEmpty
                                ? 'No completed visits in this period.'
                                : 'No completed visits for this client in '
                                    'this period.',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        for (final visit in controller.exportableVisits)
                          _VisitExportTile(
                            controller: controller,
                            visit: visit,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: AppColors.surface,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: PageContent(
                width: PageContentWidth.workflow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      enabled: controller.selectedVisitsReady,
                      label:
                          controller.selectedVisitIds.isEmpty
                              ? 'Create export'
                              : 'Create export with '
                                  '${controller.selectedVisitIds.length} visits',
                      child: AsyncElevatedButton(
                        onPressed:
                            controller.selectedVisitsReady
                                ? controller.createExport
                                : null,
                        isLoading: controller.isSaving.value,
                        child: Text(
                          controller.selectedVisitIds.isEmpty
                              ? 'Create export'
                              : 'Create export '
                                  '(${controller.selectedVisitIds.length})',
                        ),
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        hint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _PeriodFilterField extends StatelessWidget {
  const _PeriodFilterField({required this.range, required this.onPick});

  final DateTimeRange range;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Period',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      child: InkWell(
        onTap: onPick,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${billingFmtYmd(range.start)} – ${billingFmtYmd(range.end)}',
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _VisitExportTile extends StatelessWidget {
  const _VisitExportTile({required this.controller, required this.visit});

  final InvoiceExportsController controller;
  final VisitOut visit;

  @override
  Widget build(BuildContext context) {
    final preflight = controller.preflightFor(visit);
    final serverErr = controller.visitErrorFor(visit.id);
    final selected = controller.selectedVisitIds.contains(visit.id);
    final showFix =
        !preflight.isReady ||
        (serverErr != null && serverErr.code != 'visit_already_exported');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: billingPanelDecoration(),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Semantics(
          label: 'Select visit for export',
          checked: selected,
          child: Checkbox(
            value: selected,
            onChanged:
                preflight.isReady
                    ? (_) => controller.toggleVisit(visit.id)
                    : null,
          ),
        ),
        title: Text(visit.jobTitle ?? 'Visit'),
        subtitle: Text(
          '${billingFmtDateTime(visit.scheduledStart)}'
          '${visit.contractorName != null ? ' · ${visit.contractorName}' : ''}',
        ),
        children: [
          if (serverErr != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                serverErr.message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          for (final check in preflight.checks) _PreflightRow(check: check),
          if (showFix)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => controller.openVisitForFix(visit),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Fix on visit'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreflightRow extends StatelessWidget {
  const _PreflightRow({required this.check});
  final VisitExportCheck check;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (check.status) {
      case VisitExportCheckStatus.ok:
        icon = Icons.check_circle_outline;
        color = AppColors.success;
      case VisitExportCheckStatus.warn:
        icon = Icons.warning_amber_outlined;
        color = AppColors.openSlot;
      case VisitExportCheckStatus.block:
        icon = Icons.error_outline;
        color = AppColors.error;
    }
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(check.label),
      subtitle: check.detail != null ? Text(check.detail!) : null,
    );
  }
}

class _BurnTab extends StatelessWidget {
  const _BurnTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.burnAlerts.toList(growable: false);
      return RefreshIndicator(
        onRefresh: controller.loadBurnAlerts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.workflow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Plan burn alerts from declared budgets vs exported ledger spend '
                    '(not a live NDIA balance). Soft warn and hard block use tenant thresholds.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty && !controller.isLoading.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text(
                        'No burn alerts — envelopes are within thresholds.',
                        style: TextStyle(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final row in rows) ...[
                      Container(
                        decoration: billingPanelDecoration(),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    row.clientName?.trim().isNotEmpty == true
                                        ? row.clientName!
                                        : row.clientId,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  row.isHard ? 'Hard block' : 'Soft warn',
                                  style: TextStyle(
                                    color:
                                        row.isHard
                                            ? AppColors.error
                                            : AppColors.openSlot,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${row.envelope} · remaining '
                              '${row.remaining != null ? '\$${row.remaining!.toStringAsFixed(2)}' : '—'}'
                              '${row.remainingPct != null ? ' (${row.remainingPct!.toStringAsFixed(0)}%)' : ''}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _PeTab extends StatelessWidget {
  const _PeTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.paymentEnquiries.toList(growable: false);
      return RefreshIndicator(
        onRefresh: controller.loadPaymentEnquiries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.workflow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Payment Enquiries (PE) — ageing bands (14/30/60 days). '
                    'This is not the 5-day invoice or 90-day claim window.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty && !controller.isLoading.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text(
                        'No payment enquiries tracked yet.',
                        style: TextStyle(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final row in rows) ...[
                      Container(
                        decoration: billingPanelDecoration(),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.clientName?.trim().isNotEmpty == true
                                  ? row.clientName!
                                  : row.clientId,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${row.status} · ${row.daysOpen}d open · ${row.riskBand}'
                              '${row.amount != null ? ' · \$${row.amount!.toStringAsFixed(2)}' : ''}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            if (row.notes != null && row.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                row.notes!,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _AgeingTab extends StatelessWidget {
  const _AgeingTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = controller.unclaimedAgeing.toList(growable: false);
      return RefreshIndicator(
        onRefresh: controller.loadUnclaimedAgeing,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.workflow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Completed visits not yet exported. From Dec 2026, '
                    'claims generally must be lodged within 90 days of delivery.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Approaching 90 days only (≥60)'),
                    value: controller.ageingApproaching90Only.value,
                    onChanged: (v) => controller.setAgeingApproaching90Only(v),
                  ),
                  if (controller.clientFilterOptions.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _clientDropdownValue(
                        controller.clientIdFilter.value,
                        controller.clientFilterOptions,
                      ),
                      items: _clientDropdownItems(controller.clientFilterOptions),
                      decoration: const InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: controller.setClientFilter,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (rows.isEmpty && !controller.isLoading.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Text(
                        'No unclaimed visits in this filter.',
                        style: TextStyle(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final row in rows) ...[
                      _AgeingTile(
                        row: row,
                        onFix: () => controller.openUnclaimedVisitForFix(row),
                        onExport: () => controller.openUnclaimedForExport(row),
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

Color _riskBandColor(String band) {
  switch (band) {
    case 'critical':
      return AppColors.error;
    case 'high':
      return AppColors.openSlot;
    case 'watch':
      return AppColors.openSlot.withValues(alpha: 0.85);
    default:
      return AppColors.textMuted;
  }
}

String _riskBandLabel(String band) {
  switch (band) {
    case 'critical':
      return '≥90 days';
    case 'high':
      return '≥75 days';
    case 'watch':
      return '≥60 days';
    default:
      return 'On track';
  }
}

class _AgeingTile extends StatelessWidget {
  const _AgeingTile({
    required this.row,
    required this.onFix,
    required this.onExport,
  });

  final UnclaimedAgeingVisitOut row;
  final VoidCallback onFix;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final title = row.jobTitle?.trim().isNotEmpty == true
        ? row.jobTitle!
        : 'Visit';
    final client = row.clientName?.trim();
    return Container(
      decoration: billingPanelDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _riskBandColor(row.riskBand).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _riskBandColor(row.riskBand).withValues(alpha: 0.45),
                  ),
                ),
                child: Text(
                  '${row.daysSinceCompleted}d · ${_riskBandLabel(row.riskBand)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _riskBandColor(row.riskBand),
                  ),
                ),
              ),
            ],
          ),
          if (client != null && client.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(client, style: const TextStyle(color: AppColors.textMuted)),
          ],
          const SizedBox(height: 4),
          Text(
            'Completed ${billingFmtDateTime(row.completedAt)}'
            '${row.contractorName != null ? ' · ${row.contractorName}' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          EqualFillRow(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: onFix,
                child: const Text('Fix on visit'),
              ),
              ElevatedButton(
                onPressed: onExport,
                child: const Text('Export'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({required this.export, required this.onTap});

  final InvoiceExportOut export;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: billingPanelDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${billingFmtDate(export.createdAt)} · '
                      '${billingFmtMoney(export.totalAmount, export.currencyCode)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        InvoiceExportStatusPill(status: export.status),
                        const SizedBox(width: 8),
                        Text(
                          '${export.lineCount} line'
                          '${export.lineCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
