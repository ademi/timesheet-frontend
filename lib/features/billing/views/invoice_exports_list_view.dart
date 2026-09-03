import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../visits/data/models/visit_models.dart';
import '../controllers/invoice_exports_controller.dart';
import '../data/models/billing_models.dart';
import '../utils/visit_export_preflight.dart';
import '../widgets/billing_ui.dart';

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
                    if (controller.canManage)
                      Semantics(
                        label: 'Export mode',
                        child: SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(
                              value: 0,
                              label: Text('Exports'),
                              icon: Icon(Icons.receipt_long_outlined, size: 18),
                            ),
                            ButtonSegment(
                              value: 1,
                              label: Text('Create'),
                              icon: Icon(Icons.add, size: 18),
                            ),
                          ],
                          selected: {tab},
                          onSelectionChanged: (next) {
                            final v = next.first;
                            if (v == 1) {
                              controller.switchToCreateTab();
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
                      showCreate
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
      return Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.loadExportableVisits,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  PageContent(
                    width: PageContentWidth.workflow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PeriodFilter(
                          range: controller.periodRange.value,
                          onPick: () => controller.pickPeriod(context),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select completed visits to export as NDIS '
                          'plan-manager CSV lines.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (controller.lastVisitErrors.isNotEmpty) ...[
                          const SizedBox(height: 12),
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
                        ],
                        const SizedBox(height: 16),
                        if (controller.exportableVisits.isEmpty &&
                            !controller.isLoading.value)
                          const Text(
                            'No completed visits in this period.',
                            style: TextStyle(color: AppColors.textMuted),
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

class _PeriodFilter extends StatelessWidget {
  const _PeriodFilter({required this.range, required this.onPick});

  final DateTimeRange range;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Period',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: billingPanelDecoration(),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${billingFmtYmd(range.start)} – ${billingFmtYmd(range.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.expand_more, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
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
